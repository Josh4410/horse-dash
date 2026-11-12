import XCTest
@testable import HorseDash

final class SpawnerTests: XCTestCase {
    private func generate(seed: UInt64, meters: CGFloat = 8000) -> (obstacles: [ObstacleSpec], hay: [HaySpec]) {
        var spawner = Spawner(seed: seed)
        return spawner.generate(upTo: meters * Tuning.unitsPerMeter)
    }

    func testNeverBlocksAllThreeLanes() {
        for seed in 1...20 as ClosedRange<UInt64> {
            let rows = Dictionary(grouping: generate(seed: seed).obstacles, by: \.z)
            for (_, row) in rows {
                let blocks = row.filter { $0.kind == .block }.count
                XCTAssertLessThan(blocks, 3, "seed \(seed) produced an impassable row")
            }
        }
    }

    func testRowsLeaveEnoughReactionTime() {
        for seed in 1...20 as ClosedRange<UInt64> {
            let zs = Set(generate(seed: seed).obstacles.map(\.z)).sorted()
            for (a, b) in zip(zs, zs.dropFirst()) {
                let meters = Double(a / Tuning.unitsPerMeter)
                let speed = Tuning.speed(atMeters: meters)
                // At least 0.55s, enough for two lane changes plus a jump.
                XCTAssertGreaterThanOrEqual((b - a) / speed, 0.55, "seed \(seed) rows too close at \(meters) m")
            }
        }
    }

    func testHayNeverOverlapsWagons() {
        for seed in 1...20 as ClosedRange<UInt64> {
            let result = generate(seed: seed)
            let blocks = result.obstacles.filter { $0.kind == .block }
            for hay in result.hay {
                XCTAssertFalse(
                    blocks.contains { $0.lane == hay.lane && abs($0.z - hay.z) < 100 },
                    "seed \(seed) put hay inside a wagon")
            }
        }
    }

    func testDifficultyIgnoresEverythingButDistance() {
        var a = Spawner(seed: 42)
        var b = Spawner(seed: 42)
        XCTAssertEqual(a.generate(upTo: 300_000).obstacles, b.generate(upTo: 300_000).obstacles)
    }

    func testSkillAssist() {
        XCTAssertEqual(SkillAssist.assistSeconds(recentRunMeters: []), 0)
        XCTAssertGreaterThan(SkillAssist.assistSeconds(recentRunMeters: [100, 120, 90]), 0)
        XCTAssertLessThan(SkillAssist.assistSeconds(recentRunMeters: [4000, 3500, 5000]), 0)
    }
}

final class PlayerModelTests: XCTestCase {
    private func run(_ player: inout PlayerModel, seconds: CGFloat) -> [PlayerEvent] {
        var events: [PlayerEvent] = []
        var t: CGFloat = 0
        while t < seconds {
            events += player.step(1 / 120)
            t += 1 / 120
        }
        return events
    }

    func testLaneChangeIsSnappyAndClamped() {
        var p = PlayerModel()
        XCTAssertEqual(p.perform(.left), [.laneChanged(-1)])
        _ = run(&p, seconds: Tuning.laneChangeDuration + 0.01)
        XCTAssertEqual(p.x, -1, accuracy: 0.001)
        XCTAssertEqual(p.perform(.left), [.laneBlocked(-1)])
        XCTAssertEqual(p.lane, 0)
    }

    func testJumpArcPeaksAndLands() {
        var p = PlayerModel()
        XCTAssertEqual(p.perform(.jump), [.jumped])
        var peak: CGFloat = 0
        var landedAt: CGFloat?
        var t: CGFloat = 0
        while t < 1 {
            let events = p.step(1 / 240)
            t += 1 / 240
            peak = max(peak, p.y)
            if events.contains(.landed) { landedAt = t; break }
        }
        XCTAssertEqual(peak, Tuning.jumpHeight, accuracy: 4)
        XCTAssertEqual(landedAt ?? 0, Tuning.jumpDuration, accuracy: 0.02)
    }

    func testSwipeDownInAirFastFallsThenSlides() {
        var p = PlayerModel()
        _ = p.perform(.jump)
        _ = run(&p, seconds: 0.15)
        XCTAssertEqual(p.perform(.slide), [.fastFall])
        let events = run(&p, seconds: 0.2)
        XCTAssertTrue(events.contains(.landed))
        XCTAssertTrue(events.contains(.slideStarted))
        XCTAssertTrue(p.isSliding)
    }

    func testJumpPressedJustBeforeLandingIsBuffered() {
        var p = PlayerModel()
        _ = p.perform(.jump)
        _ = run(&p, seconds: Tuning.jumpDuration - 0.08)
        XCTAssertEqual(p.perform(.jump), [])
        let events = run(&p, seconds: 0.12)
        XCTAssertTrue(events.contains(.jumped))
    }

    func testJumpCancelsSlide() {
        var p = PlayerModel()
        _ = p.perform(.slide)
        XCTAssertEqual(p.perform(.jump), [.slideEnded, .jumped])
    }
}

final class BiomeTests: XCTestCase {
    func testBiomeOrderAndLoop() {
        XCTAssertEqual(Biomes.biome(atMeters: 0).name, "Sunny Farm")
        XCTAssertEqual(Biomes.biome(atMeters: 449).name, "Sunny Farm")
        XCTAssertEqual(Biomes.biome(atMeters: 450).name, "Golden Fields")
        let total = Biomes.all.reduce(0) { $0 + $1.lengthMeters }
        // After a full cycle, the farm is skipped.
        XCTAssertEqual(Biomes.biome(atMeters: total + 1).name, "Golden Fields")
    }

    func testProjection() {
        let p = Projection(horizonY: 500, groundY: 140)
        XCTAssertEqual(p.point(0, 0, 0).y, 140, accuracy: 0.001)
        XCTAssertEqual(p.point(0, 50, 0).y, 190, accuracy: 0.001)
        XCTAssertEqual(p.point(100, 0, 1_000_000).y, 500, accuracy: 1)
    }
}

final class GameStoreTests: XCTestCase {
    private func freshStore() -> GameStore {
        let name = "test.\(UUID().uuidString)"
        return GameStore(defaults: UserDefaults(suiteName: name)!)
    }

    func testPurchaseFlow() {
        let store = freshStore()
        let skin = Skins.all[1]
        XCTAssertEqual(store.buy(skin), .insufficientFunds)
        store.recordRun(meters: 100, hay: skin.price, biome: "Sunny Farm")
        XCTAssertEqual(store.buy(skin), .purchased)
        XCTAssertEqual(store.hayBales, 0)
        XCTAssertEqual(store.selectedSkin, skin.id)
        XCTAssertEqual(store.buy(skin), .alreadyOwned)
    }

    func testHighScoresSortedAndCapped() {
        let store = freshStore()
        for m in 1...15 { store.recordRun(meters: m * 10, hay: 0, biome: "x") }
        XCTAssertEqual(store.highScores.count, GameStore.maxScores)
        XCTAssertEqual(store.best, 150)
        XCTAssertEqual(store.highScores.map(\.meters), store.highScores.map(\.meters).sorted(by: >))
    }

    func testReviveDoesNotChangeRecordedScore() {
        let store = freshStore()
        store.recordRun(meters: 1234, hay: 5, biome: "x")
        XCTAssertEqual(store.best, 1234)
    }
}
