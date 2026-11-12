import CoreGraphics
import Foundation

/// Every gameplay number lives here so feel can be tuned in one place.
///
/// World units: 1 unit is roughly 1 screen point at the player's depth.
/// `z` is distance ahead of the player, `y` is height above the ground.
enum Tuning {
    // Camera / world
    static let cameraDepth: CGFloat = 520
    static let spawnAhead: CGFloat = 9000
    static let unitsPerMeter: CGFloat = 100
    static let bandSpacing: CGFloat = 400
    static let dashSpacing: CGFloat = 320
    static let dashLength: CGFloat = 150

    // Speed (depends only on distance, identical for every player)
    static let startSpeed: CGFloat = 1500
    static let maxSpeed: CGFloat = 3000
    static let speedRampMeters: Double = 1800

    static func speed(atMeters meters: Double) -> CGFloat {
        startSpeed + (maxSpeed - startSpeed) * CGFloat(1 - exp(-max(0, meters) / speedRampMeters))
    }

    // Player feel
    static let laneChangeDuration: CGFloat = 0.11
    static let jumpHeight: CGFloat = 210
    static let jumpDuration: CGFloat = 0.58
    static let fastFallSpeed: CGFloat = 2600
    static let slideDuration: CGFloat = 0.62
    static let inputBufferWindow: CGFloat = 0.18
    static let swipeThreshold: CGFloat = 22

    // Obstacles (world units at the player's depth)
    static let hurdleHeight: CGFloat = 84
    static let hurdleClearY: CGFloat = 64
    static let overheadHeight: CGFloat = 210
    static let overheadClearance: CGFloat = 105
    static let blockHeight: CGFloat = 250
    static let hayDiameter: CGFloat = 46

    // Revive
    static let reviveInvulnerability: CGFloat = 2.0
    static let reviveClearDistance: CGFloat = 3000
}
