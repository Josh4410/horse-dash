import Foundation
import UIKit

// MARK: - Analytics

/// Plug a real backend in by replacing `Analytics.shared.sink`.
protocol AnalyticsSink {
    func send(_ name: String, _ params: [String: String])
}

struct ConsoleAnalyticsSink: AnalyticsSink {
    func send(_ name: String, _ params: [String: String]) {
        #if DEBUG
        let body = params.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        print("[analytics] \(name) \(body)")
        #endif
    }
}

/// Standard product analytics. Every field collected is listed in Settings,
/// and the player can switch it off. Nothing here affects gameplay.
final class Analytics {
    static let shared = Analytics()
    var sink: AnalyticsSink = ConsoleAnalyticsSink()

    private init() {}

    /// Shown verbatim in Settings so the disclosure always matches the code.
    static let collectedFields = [
        "Device model (e.g. iPhone15,2)",
        "Country / region from your device settings",
        "Music and vibration on/off",
        "App version",
        "Run length, hay collected, revive prompt choices",
    ]

    func log(_ name: String, _ params: [String: String] = [:]) {
        let settings = GameStore.shared.settings
        guard settings.analytics else { return }
        var all = commonParams(settings)
        all.merge(params) { _, new in new }
        sink.send(name, all)
    }

    private func commonParams(_ s: AppSettings) -> [String: String] {
        [
            "device_model": Self.deviceModel,
            "country": Locale.current.region?.identifier ?? "unknown",
            "music_on": s.music ? "1" : "0",
            "vibration_on": s.vibration ? "1" : "0",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
        ]
    }

    static let deviceModel: String = {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }()
}

// MARK: - Rewarded ads

/// Hook for a real ad SDK. The game only asks "is an ad ready?" and
/// "show it"; ad value never influences gameplay.
protocol RewardedAdProvider: AnyObject {
    var isReady: Bool { get }
    func load()
    func show(completion: @escaping (_ rewarded: Bool) -> Void)
}

final class StubRewardedAdProvider: RewardedAdProvider {
    var isReady = true

    func load() { isReady = true }

    func show(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            completion(true)
        }
    }
}

enum Ads {
    static var rewarded: RewardedAdProvider = StubRewardedAdProvider()
}

// MARK: - Revive prompt A/B test

/// Ordinary UI experiment on the revive prompt. Assigned once per install,
/// shown in Settings, and only changes the prompt's wording and countdown.
enum ReviveVariant: String, CaseIterable {
    case quick
    case relaxed

    var countdownSeconds: Int { self == .quick ? 5 : 8 }

    var headline: String { self == .quick ? "Second wind?" : "Keep the run going?" }

    var label: String { self == .quick ? "A (5s prompt)" : "B (8s prompt)" }
}

enum ReviveExperiment {
    private static let key = "horsedash.experiment.revive"

    static var variant: ReviveVariant {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: key), let v = ReviveVariant(rawValue: raw) {
            return v
        }
        let v = ReviveVariant.allCases.randomElement() ?? .quick
        defaults.set(v.rawValue, forKey: key)
        return v
    }
}
