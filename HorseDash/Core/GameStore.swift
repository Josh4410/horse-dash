import Combine
import Foundation

struct ScoreEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    let meters: Int
    let hay: Int
    let biome: String
    let date: Date
}

struct AppSettings: Codable, Equatable {
    var vibration = true
    var music = true
    var soundEffects = true
    var reduceCameraShake = false
    var dynamicDifficulty = true
    var analytics = true
}

/// Persistent player progress: hay bales, high scores, skins and settings.
final class GameStore: ObservableObject {
    static let shared = GameStore()
    static let maxScores = 10

    private struct SaveData: Codable {
        var hayBales = 0
        var highScores: [ScoreEntry] = []
        var ownedSkins: [String] = [Skins.defaultID]
        var selectedSkin = Skins.defaultID
        var settings = AppSettings()
        var recentRuns: [Int] = []
    }

    enum PurchaseResult: Equatable {
        case purchased, alreadyOwned, insufficientFunds
    }

    @Published private(set) var hayBales: Int
    @Published private(set) var highScores: [ScoreEntry]
    @Published private(set) var ownedSkins: Set<String>
    @Published private(set) var recentRuns: [Int]
    @Published var selectedSkin: String { didSet { save() } }
    @Published var settings: AppSettings {
        didSet {
            save()
            if settings != oldValue { Analytics.shared.log("settings_changed") }
        }
    }

    private let defaults: UserDefaults
    private let key = "horsedash.save.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var data = SaveData()
        if let raw = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(SaveData.self, from: raw) {
            data = decoded
        }
        hayBales = data.hayBales
        highScores = data.highScores
        ownedSkins = Set(data.ownedSkins).union([Skins.defaultID])
        recentRuns = data.recentRuns
        selectedSkin = data.selectedSkin
        settings = data.settings
    }

    var best: Int { highScores.first?.meters ?? 0 }

    /// Records a finished run. Returns true when it is a new personal best.
    @discardableResult
    func recordRun(meters: Int, hay: Int, biome: String) -> Bool {
        let isBest = meters > best
        hayBales += hay
        recentRuns.insert(meters, at: 0)
        recentRuns = Array(recentRuns.prefix(5))
        if meters > 0 {
            highScores.append(ScoreEntry(meters: meters, hay: hay, biome: biome, date: Date()))
            highScores.sort { $0.meters > $1.meters }
            highScores = Array(highScores.prefix(Self.maxScores))
        }
        save()
        return isBest
    }

    func owns(_ skin: Skin) -> Bool { ownedSkins.contains(skin.id) }

    func buy(_ skin: Skin) -> PurchaseResult {
        if owns(skin) { return .alreadyOwned }
        guard hayBales >= skin.price else { return .insufficientFunds }
        hayBales -= skin.price
        ownedSkins.insert(skin.id)
        selectedSkin = skin.id
        save()
        Analytics.shared.log("skin_purchased", ["skin": skin.id, "price": String(skin.price)])
        return .purchased
    }

    func resetProgress() {
        hayBales = 0
        highScores = []
        recentRuns = []
        ownedSkins = [Skins.defaultID]
        selectedSkin = Skins.defaultID
        save()
    }

    private func save() {
        let data = SaveData(
            hayBales: hayBales,
            highScores: highScores,
            ownedSkins: Array(ownedSkins),
            selectedSkin: selectedSkin,
            settings: settings,
            recentRuns: recentRuns)
        if let raw = try? JSONEncoder().encode(data) {
            defaults.set(raw, forKey: key)
        }
    }
}
