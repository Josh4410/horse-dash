import CoreGraphics

enum ObstacleKind: CaseIterable {
    /// Low show-jumping poles: jump over.
    case hurdle
    /// Beam overhead: slide under.
    case overhead
    /// Tall wagon: change lane.
    case block
}

struct ObstacleSpec: Equatable {
    let lane: Int
    let kind: ObstacleKind
    let z: CGFloat
}

struct HaySpec: Equatable {
    let lane: Int
    let z: CGFloat
    let height: CGFloat
}

/// Small deterministic RNG so spawn patterns are reproducible in tests.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Generates obstacle rows and hay bale trails ahead of the player.
///
/// Fairness rules:
/// - Difficulty depends only on distance (plus the optional, player-visible
///   skill assist), never on anything about the player's ads or spending.
/// - A row never blocks all three lanes with wagons.
/// - Rows are always far enough apart to react and change two lanes.
struct Spawner {
    static let laneCount = 3

    private(set) var nextRowZ: CGFloat
    private var rng: SplitMix64
    /// Extra seconds of reaction time between rows. Positive is easier.
    /// Set from `SkillAssist` when Dynamic difficulty is on, otherwise 0.
    var assistSeconds: CGFloat = 0

    init(seed: UInt64, firstRowZ: CGFloat = 2600) {
        rng = SplitMix64(seed: seed)
        nextRowZ = firstRowZ
    }

    static func difficulty(meters: Double) -> CGFloat {
        CGFloat(min(max(meters / 3000, 0), 1))
    }

    /// Seconds between rows at a given difficulty, before random slack.
    static func reactionSeconds(difficulty d: CGFloat) -> CGFloat {
        0.95 - 0.33 * d
    }

    mutating func generate(upTo z: CGFloat) -> (obstacles: [ObstacleSpec], hay: [HaySpec]) {
        var obstacles: [ObstacleSpec] = []
        var hay: [HaySpec] = []
        while nextRowZ < z {
            let rowZ = nextRowZ
            let meters = Double(rowZ / Tuning.unitsPerMeter)
            let d = Self.difficulty(meters: meters)
            let speed = Tuning.speed(atMeters: meters)
            let row = makeRow(difficulty: d)
            for (lane, kind) in row.enumerated() {
                if let kind { obstacles.append(ObstacleSpec(lane: lane, kind: kind, z: rowZ)) }
            }
            let reaction = max(0.55, Self.reactionSeconds(difficulty: d) + assistSeconds)
            let gap = speed * reaction + CGFloat.random(in: 0...(speed * 0.45), using: &rng)
            hay += makeHay(row: row, rowZ: rowZ, gap: gap)
            nextRowZ += gap
        }
        return (obstacles, hay)
    }

    private mutating func makeRow(difficulty d: CGFloat) -> [ObstacleKind?] {
        var row: [ObstacleKind?] = [nil, nil, nil]
        let roll = CGFloat.random(in: 0..<1, using: &rng)
        let count: Int
        if roll < 0.6 - 0.35 * d {
            count = 1
        } else if roll < 0.93 - 0.18 * d {
            count = 2
        } else {
            count = 3
        }
        let lanes = [0, 1, 2].shuffled(using: &rng)
        for lane in lanes.prefix(count) {
            row[lane] = randomKind(difficulty: d)
        }
        // Always leave a way through.
        if !row.contains(where: { $0 != .block }) {
            row[lanes[0]] = Bool.random(using: &rng) ? .hurdle : nil
        }
        return row
    }

    private mutating func randomKind(difficulty d: CGFloat) -> ObstacleKind {
        let r = CGFloat.random(in: 0..<1, using: &rng)
        let blockWeight = 0.4 + 0.1 * d
        if r < blockWeight { return .block }
        if r < blockWeight + 0.32 { return .hurdle }
        return .overhead
    }

    private mutating func makeHay(row: [ObstacleKind?], rowZ: CGFloat, gap: CGFloat) -> [HaySpec] {
        var out: [HaySpec] = []
        // Arcs over hurdles reward a clean jump.
        for (lane, kind) in row.enumerated() where kind == .hurdle && Bool.random(using: &rng) {
            let heights: [CGFloat] = [90, 170, 215, 170, 90]
            for (i, h) in heights.enumerated() {
                out.append(HaySpec(lane: lane, z: rowZ + CGFloat(i - 2) * 110 + 20, height: h))
            }
        }
        // Trails in a free lane between this row and the next.
        if CGFloat.random(in: 0..<1, using: &rng) < 0.75 {
            let free = (0..<Self.laneCount).filter { row[$0] == nil }
            if let lane = free.randomElement(using: &rng) {
                var z = rowZ + 220
                let end = rowZ + gap - 260
                var placed = 0
                while z <= end && placed < 12 {
                    out.append(HaySpec(lane: lane, z: z, height: 40))
                    z += 120
                    placed += 1
                }
            }
        }
        return out
    }
}

/// Optional, player-visible dynamic difficulty based only on recent run lengths.
/// Short recent runs give a little more reaction time; long runs take a little away.
enum SkillAssist {
    static func assistSeconds(recentRunMeters: [Int]) -> CGFloat {
        let recent = recentRunMeters.prefix(3)
        guard recent.count >= 2 else { return 0 }
        let avg = Double(recent.reduce(0, +)) / Double(recent.count)
        if avg < 250 { return 0.12 }
        if avg < 600 { return 0.06 }
        if avg > 3000 { return -0.05 }
        return 0
    }
}
