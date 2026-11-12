import CoreGraphics

/// Plain RGB colour so game data stays free of UIKit and is easy to test.
struct RGB: Equatable {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat

    init(_ hex: UInt32) {
        r = CGFloat((hex >> 16) & 0xFF) / 255
        g = CGFloat((hex >> 8) & 0xFF) / 255
        b = CGFloat(hex & 0xFF) / 255
    }

    init(r: CGFloat, g: CGFloat, b: CGFloat) {
        self.r = r
        self.g = g
        self.b = b
    }

    func mix(_ other: RGB, _ t: CGFloat) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    func shade(_ f: CGFloat) -> RGB {
        RGB(r: min(1, r * f), g: min(1, g * f), b: min(1, b * f))
    }
}

struct BiomePalette: Equatable {
    var skyTop: RGB
    var skyBottom: RGB
    var sun: RGB
    var hills: RGB
    var ground: RGB
    var road: RGB
    var kerb: RGB
    var laneLine: RGB

    func mix(_ o: BiomePalette, _ t: CGFloat) -> BiomePalette {
        BiomePalette(
            skyTop: skyTop.mix(o.skyTop, t),
            skyBottom: skyBottom.mix(o.skyBottom, t),
            sun: sun.mix(o.sun, t),
            hills: hills.mix(o.hills, t),
            ground: ground.mix(o.ground, t),
            road: road.mix(o.road, t),
            kerb: kerb.mix(o.kerb, t),
            laneLine: laneLine.mix(o.laneLine, t)
        )
    }
}

enum DecorKind: CaseIterable {
    case tree, barn, sunflower, cactus, mesa, pine, snowman, lavaRock, crystal, lollipop, gumdrop
}

struct Biome {
    let name: String
    let lengthMeters: Double
    let palette: BiomePalette
    let obstacleMain: RGB
    let obstacleAccent: RGB
    let decor: [DecorKind]
    let pointyHills: Bool
}

enum Biomes {
    static let all: [Biome] = [
        Biome(
            name: "Sunny Farm", lengthMeters: 450,
            palette: BiomePalette(
                skyTop: RGB(0x3FB8F5), skyBottom: RGB(0xBDEBFF), sun: RGB(0xFFF176), hills: RGB(0x4CB944),
                ground: RGB(0x7CD13A), road: RGB(0xD9965A), kerb: RGB(0xFFFFFF), laneLine: RGB(0xFFE9B0)),
            obstacleMain: RGB(0xE53935), obstacleAccent: RGB(0xFFFFFF),
            decor: [.tree, .barn, .tree], pointyHills: false),
        Biome(
            name: "Golden Fields", lengthMeters: 600,
            palette: BiomePalette(
                skyTop: RGB(0x29A8F0), skyBottom: RGB(0xFFF59D), sun: RGB(0xFFEE58), hills: RGB(0x66BB6A),
                ground: RGB(0xB5D93B), road: RGB(0x9B6B4B), kerb: RGB(0xFFC107), laneLine: RGB(0xFFF8E1)),
            obstacleMain: RGB(0x7B3FA0), obstacleAccent: RGB(0xFFC107),
            decor: [.sunflower, .tree, .sunflower], pointyHills: false),
        Biome(
            name: "Blazing Desert", lengthMeters: 700,
            palette: BiomePalette(
                skyTop: RGB(0xFF7A45), skyBottom: RGB(0xFFE0A3), sun: RGB(0xFFFDE7), hills: RGB(0xF57C00),
                ground: RGB(0xFFB547), road: RGB(0xE69A4C), kerb: RGB(0xC2185B), laneLine: RGB(0xFFF3E0)),
            obstacleMain: RGB(0x00897B), obstacleAccent: RGB(0xFFEB3B),
            decor: [.cactus, .mesa, .cactus], pointyHills: false),
        Biome(
            name: "Frosty Peaks", lengthMeters: 750,
            palette: BiomePalette(
                skyTop: RGB(0x5468D4), skyBottom: RGB(0xB3E8FF), sun: RGB(0xFFFFFF), hills: RGB(0xF4FAFF),
                ground: RGB(0xEAF6FF), road: RGB(0xBFDFFF), kerb: RGB(0x1E9BF0), laneLine: RGB(0xFFFFFF)),
            obstacleMain: RGB(0x0277BD), obstacleAccent: RGB(0xFF4081),
            decor: [.pine, .snowman, .pine], pointyHills: true),
        Biome(
            name: "Lava Ridge", lengthMeters: 800,
            palette: BiomePalette(
                skyTop: RGB(0x3A0A2A), skyBottom: RGB(0xFF5A2E), sun: RGB(0xFF1744), hills: RGB(0x5D1A1A),
                ground: RGB(0x2E1C1C), road: RGB(0x4E342E), kerb: RGB(0xFF3D00), laneLine: RGB(0xFFAB00)),
            obstacleMain: RGB(0x455A64), obstacleAccent: RGB(0xFF9100),
            decor: [.lavaRock, .lavaRock, .crystal], pointyHills: true),
        Biome(
            name: "Aurora Plains", lengthMeters: 850,
            palette: BiomePalette(
                skyTop: RGB(0x0D0B3E), skyBottom: RGB(0x1DE9B6), sun: RGB(0xFFFFFF), hills: RGB(0x311B92),
                ground: RGB(0x1A237E), road: RGB(0x303F9F), kerb: RGB(0x00E5FF), laneLine: RGB(0xE040FB)),
            obstacleMain: RGB(0x7C4DFF), obstacleAccent: RGB(0x18FFFF),
            decor: [.crystal, .pine, .crystal], pointyHills: true),
        Biome(
            name: "Sugar Meadow", lengthMeters: 900,
            palette: BiomePalette(
                skyTop: RGB(0xF48FB1), skyBottom: RGB(0xFFF9C4), sun: RGB(0xFFF59D), hills: RGB(0xCE93D8),
                ground: RGB(0x8EF0C0), road: RGB(0xF8BBD0), kerb: RGB(0xFFFFFF), laneLine: RGB(0xE91E63)),
            obstacleMain: RGB(0xEC407A), obstacleAccent: RGB(0xFFFFFF),
            decor: [.lollipop, .gumdrop, .lollipop], pointyHills: false),
    ]

    /// Biomes play in order once, then loop from the second one (the farm is only the start).
    static func biomeIndex(forStage stage: Int) -> Int {
        stage < all.count ? stage : 1 + (stage - all.count) % (all.count - 1)
    }

    /// Monotonic stage counter for a distance. Changes exactly when a new biome begins.
    static func stage(atMeters meters: Double) -> Int {
        var end = 0.0
        var stage = 0
        while true {
            end += all[biomeIndex(forStage: stage)].lengthMeters
            if meters < end { return stage }
            stage += 1
        }
    }

    static func index(atMeters meters: Double) -> Int {
        biomeIndex(forStage: stage(atMeters: meters))
    }

    static func biome(atMeters meters: Double) -> Biome {
        all[index(atMeters: meters)]
    }
}
