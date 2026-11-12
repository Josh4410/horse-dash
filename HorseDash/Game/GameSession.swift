import Combine
import SpriteKit

/// Bridges one run of the SpriteKit scene to the SwiftUI screens.
final class GameSession: ObservableObject, GameSceneDelegate {
    enum Phase: Equatable {
        case running, paused, reviveOffer, watchingAd, gameOver
    }

    @Published private(set) var meters = 0
    @Published private(set) var hay = 0
    @Published private(set) var phase: Phase = .running
    @Published private(set) var biomeName: String
    @Published private(set) var banner: String?
    @Published private(set) var hasRevived = false
    @Published private(set) var isNewBest = false
    @Published private(set) var reviveSecondsLeft = 0

    let scene: GameScene
    let reviveVariant: ReviveVariant
    let bestAtStart: Int

    private let store: GameStore
    private var countdown: Timer?
    private var bannerWork: DispatchWorkItem?

    init(store: GameStore = .shared, size: CGSize) {
        self.store = store
        reviveVariant = ReviveExperiment.variant
        bestAtStart = store.best
        biomeName = Biomes.all[0].name
        let assist = store.settings.dynamicDifficulty
            ? SkillAssist.assistSeconds(recentRunMeters: store.recentRuns)
            : 0
        scene = GameScene(size: size, skin: Skins.skin(id: store.selectedSkin),
                          settings: store.settings, assistSeconds: assist)
        scene.scaleMode = .resizeFill
        scene.gameDelegate = self
        Haptics.shared.prepare()
        Ads.rewarded.load()
        Analytics.shared.log("run_start", ["skin": store.selectedSkin])
        showBanner(biomeName)
    }

    deinit {
        countdown?.invalidate()
    }

    // MARK: Controls

    func pause() {
        guard phase == .running else { return }
        phase = .paused
        scene.setGameplayPaused(true)
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .running
        scene.setGameplayPaused(false)
    }

    /// Ends the run early from the pause menu; hay collected so far is kept.
    func quit() {
        guard phase == .paused else { return }
        finish(reason: "quit")
    }

    func acceptRevive() {
        guard phase == .reviveOffer else { return }
        stopCountdown()
        Analytics.shared.log("revive_prompt_accepted", ["variant": reviveVariant.rawValue])
        phase = .watchingAd
        Ads.rewarded.show { [weak self] rewarded in
            guard let self else { return }
            if rewarded {
                self.hasRevived = true
                self.phase = .running
                self.scene.revive()
                Analytics.shared.log("revive_used", ["meters": String(self.meters)])
            } else {
                self.finish(reason: "ad_failed")
            }
        }
    }

    func declineRevive() {
        guard phase == .reviveOffer else { return }
        stopCountdown()
        Analytics.shared.log("revive_prompt_declined", ["variant": reviveVariant.rawValue])
        finish(reason: "crash")
    }

    // MARK: GameSceneDelegate

    func sceneDidUpdate(meters: Int, hay: Int) {
        self.meters = meters
        self.hay = hay
    }

    func sceneDidEnterBiome(_ biome: Biome) {
        biomeName = biome.name
        showBanner(biome.name)
    }

    func sceneDidCrash() {
        if !hasRevived && Ads.rewarded.isReady {
            phase = .reviveOffer
            Analytics.shared.log("revive_prompt_shown", ["variant": reviveVariant.rawValue])
            startCountdown()
        } else {
            finish(reason: "crash")
        }
    }

    // MARK: Internals

    private func finish(reason: String) {
        stopCountdown()
        isNewBest = store.recordRun(meters: meters, hay: hay, biome: biomeName)
        phase = .gameOver
        Analytics.shared.log("run_end", [
            "meters": String(meters), "hay": String(hay), "biome": biomeName,
            "revived": hasRevived ? "1" : "0", "reason": reason,
        ])
    }

    private func startCountdown() {
        reviveSecondsLeft = reviveVariant.countdownSeconds
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.reviveSecondsLeft -= 1
            if self.reviveSecondsLeft <= 0 {
                Analytics.shared.log("revive_prompt_timeout", ["variant": self.reviveVariant.rawValue])
                self.stopCountdown()
                self.finish(reason: "crash")
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdown = timer
    }

    private func stopCountdown() {
        countdown?.invalidate()
        countdown = nil
    }

    private func showBanner(_ text: String) {
        bannerWork?.cancel()
        banner = text
        let work = DispatchWorkItem { [weak self] in self?.banner = nil }
        bannerWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }
}
