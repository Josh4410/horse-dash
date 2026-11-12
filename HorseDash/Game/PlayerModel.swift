import CoreGraphics

enum PlayerAction: Equatable {
    case left, right, jump, slide
}

enum PlayerEvent: Equatable {
    case laneChanged(Int)
    case laneBlocked(Int)
    case jumped
    case landed
    case slideStarted
    case slideEnded
    case fastFall
}

/// Pure movement model: lanes, jump arc, slide, and input buffering.
/// The scene only renders it, which keeps feel testable.
struct PlayerModel {
    static let gravity = 8 * Tuning.jumpHeight / (Tuning.jumpDuration * Tuning.jumpDuration)
    static let jumpVelocity = 4 * Tuning.jumpHeight / Tuning.jumpDuration

    private(set) var lane: Int
    /// Lane coordinate, -1 (left) ... 1 (right).
    private(set) var x: CGFloat
    private(set) var y: CGFloat = 0
    private(set) var vy: CGFloat = 0
    private(set) var slideTimer: CGFloat = 0

    private var laneFromX: CGFloat
    private var laneT: CGFloat = 1
    private var buffered: PlayerAction?
    private var bufferAge: CGFloat = 0

    init(lane: Int = 1) {
        self.lane = lane
        x = Self.laneX(lane)
        laneFromX = x
    }

    static func laneX(_ lane: Int) -> CGFloat { CGFloat(lane - 1) }

    var isAirborne: Bool { y > 0 || vy > 0 }
    var isSliding: Bool { slideTimer > 0 }

    mutating func perform(_ action: PlayerAction) -> [PlayerEvent] {
        switch action {
        case .left:
            return changeLane(-1)
        case .right:
            return changeLane(1)
        case .jump:
            if isAirborne {
                buffer(.jump)
                return []
            }
            var events: [PlayerEvent] = []
            if isSliding {
                slideTimer = 0
                events.append(.slideEnded)
            }
            vy = Self.jumpVelocity
            events.append(.jumped)
            return events
        case .slide:
            if isAirborne {
                vy = min(vy, -Tuning.fastFallSpeed)
                buffer(.slide)
                return [.fastFall]
            }
            let wasSliding = isSliding
            slideTimer = Tuning.slideDuration
            return wasSliding ? [] : [.slideStarted]
        }
    }

    mutating func step(_ dt: CGFloat) -> [PlayerEvent] {
        var events: [PlayerEvent] = []

        if laneT < 1 {
            laneT = min(1, laneT + dt / Tuning.laneChangeDuration)
            let inv = 1 - laneT
            let eased = 1 - inv * inv * inv // ease-out cubic: fast start, soft settle
            x = laneFromX + (Self.laneX(lane) - laneFromX) * eased
        }

        if isAirborne {
            vy -= Self.gravity * dt
            y += vy * dt
            if y <= 0 {
                y = 0
                vy = 0
                events.append(.landed)
                if let action = buffered, bufferAge <= Tuning.inputBufferWindow {
                    buffered = nil
                    events += perform(action)
                }
            }
        }

        if slideTimer > 0 {
            slideTimer -= dt
            if slideTimer <= 0 {
                slideTimer = 0
                events.append(.slideEnded)
            }
        }

        if buffered != nil {
            bufferAge += dt
            if bufferAge > Tuning.inputBufferWindow { buffered = nil }
        }
        return events
    }

    private mutating func changeLane(_ dir: Int) -> [PlayerEvent] {
        let target = lane + dir
        guard (0..<Spawner.laneCount).contains(target) else { return [.laneBlocked(dir)] }
        lane = target
        laneFromX = x
        laneT = 0
        return [.laneChanged(dir)]
    }

    private mutating func buffer(_ action: PlayerAction) {
        buffered = action
        bufferAge = 0
    }
}

/// Perspective projection for the pseudo-3D track.
struct Projection {
    var horizonY: CGFloat = 500
    var groundY: CGFloat = 140
    let depth = Tuning.cameraDepth

    func scale(_ z: CGFloat) -> CGFloat {
        depth / max(z + depth, 1)
    }

    func point(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint {
        let s = scale(z)
        return CGPoint(x: x * s, y: horizonY - (horizonY - groundY - y) * s)
    }
}
