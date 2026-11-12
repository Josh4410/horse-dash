import CoreHaptics
import UIKit

/// All game haptics. Generators are kept prepared so the Taptic Engine
/// fires on the same frame as the input, and every call respects the
/// Vibration toggle in settings.
final class Haptics {
    static let shared = Haptics()

    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notify = UINotificationFeedbackGenerator()

    private var engine: CHHapticEngine?
    private var lastCoin: CFTimeInterval = 0
    private var coinFlip = false

    private var enabled: Bool { GameStore.shared.settings.vibration }

    private init() {}

    /// Call at app launch and at the start of each run.
    func prepare() {
        guard enabled else { return }
        [rigid, light, medium, soft, heavy].forEach { $0.prepare() }
        selection.prepare()
        notify.prepare()
        startEngine()
    }

    // MARK: Gameplay

    func laneChange() { impact(rigid, 0.6) }
    func laneBlocked() { impact(heavy, 0.45) }
    func jump() { impact(medium, 0.75) }
    func land() { impact(soft, 0.85) }
    func slide() { impact(soft, 0.65) }
    func fastFall() { impact(rigid, 0.5) }

    func hay() {
        guard enabled else { return }
        let now = CACurrentMediaTime()
        guard now - lastCoin > 0.045 else { return }
        lastCoin = now
        coinFlip.toggle()
        impact(light, coinFlip ? 0.45 : 0.32)
    }

    func crash() {
        guard enabled else { return }
        if !play(Self.crashPattern) {
            heavy.impactOccurred(intensity: 1)
            notify.notificationOccurred(.error)
        }
        heavy.prepare()
    }

    func biomeChange() {
        guard enabled else { return }
        if !play(Self.risingPattern(intensities: [0.35, 0.55, 0.85], spacing: 0.08)) {
            notify.notificationOccurred(.success)
        }
    }

    func revive() {
        guard enabled else { return }
        if !play(Self.risingPattern(intensities: [0.4, 0.6, 0.8, 1.0], spacing: 0.06)) {
            notify.notificationOccurred(.success)
        }
    }

    // MARK: UI

    func tap() {
        guard enabled else { return }
        selection.selectionChanged()
        selection.prepare()
    }

    func success() {
        guard enabled else { return }
        notify.notificationOccurred(.success)
        notify.prepare()
    }

    func error() {
        guard enabled else { return }
        notify.notificationOccurred(.error)
        notify.prepare()
    }

    /// Played when the player switches vibration on, so they feel it right away.
    func preview() {
        prepare()
        impact(medium, 0.8)
    }

    // MARK: Internals

    private func impact(_ generator: UIImpactFeedbackGenerator, _ intensity: CGFloat) {
        guard enabled else { return }
        generator.impactOccurred(intensity: intensity)
        generator.prepare()
    }

    private func startEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if engine == nil {
            engine = try? CHHapticEngine()
            engine?.playsHapticsOnly = true
            engine?.isAutoShutdownEnabled = true
            engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
            engine?.stoppedHandler = { _ in }
        }
        try? engine?.start()
    }

    @discardableResult
    private func play(_ pattern: CHHapticPattern?) -> Bool {
        guard let pattern else { return false }
        startEngine()
        guard let engine, let player = try? engine.makePlayer(with: pattern) else { return false }
        do {
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }

    /// Sharp hit followed by a fast-decaying rumble.
    private static let crashPattern: CHHapticPattern? = {
        let hit = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9),
            ],
            relativeTime: 0)
        let rumble = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
            ],
            relativeTime: 0.02,
            duration: 0.38)
        let fade = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 1),
                CHHapticParameterCurve.ControlPoint(relativeTime: 0.38, value: 0),
            ],
            relativeTime: 0.02)
        return try? CHHapticPattern(events: [hit, rumble], parameterCurves: [fade])
    }()

    private static func risingPattern(intensities: [Float], spacing: TimeInterval) -> CHHapticPattern? {
        let events = intensities.enumerated().map { i, value in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: value),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4 + value * 0.4),
                ],
                relativeTime: TimeInterval(i) * spacing)
        }
        return try? CHHapticPattern(events: events, parameters: [])
    }
}
