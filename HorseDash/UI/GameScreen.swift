import SpriteKit
import SwiftUI

struct GameScreen: View {
    @ObservedObject var session: GameSession
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: GameStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SpriteView(scene: session.scene, preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            HUDView(session: session)

            switch session.phase {
            case .running:
                EmptyView()
            case .paused:
                PauseOverlay(session: session)
            case .reviveOffer:
                ReviveOverlay(session: session)
            case .watchingAd:
                AdPlaceholderOverlay()
            case .gameOver:
                GameOverOverlay(session: session)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: session.phase)
        .onChange(of: scenePhase) { phase in
            if phase != .active { session.pause() }
        }
    }
}

// MARK: - HUD

struct HUDView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                Button {
                    session.pause()
                } label: {
                    Image(systemName: "pause.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.orange, fontSize: 18, fullWidth: false))
                .opacity(session.phase == .running ? 1 : 0)

                Spacer()

                VStack(spacing: 0) {
                    Text("\(session.meters)")
                        .font(Theme.font(44))
                        .monospacedDigit()
                    Text("METERS")
                        .font(Theme.font(12))
                        .opacity(0.85)
                }
                .foregroundColor(.white)
                .shadow(color: Theme.ink.opacity(0.6), radius: 0, x: 0, y: 3)
                .allowsHitTesting(false)

                Spacer()

                HayBadge(count: session.hay)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 16)

            if session.bestAtStart > 0 && session.meters > session.bestAtStart {
                Text("NEW BEST!")
                    .font(Theme.font(16))
                    .foregroundColor(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.sun))
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            if let banner = session.banner {
                Text(banner.uppercased())
                    .font(Theme.font(26))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.ink.opacity(0.45)))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .padding(.top, 30)
                    .allowsHitTesting(false)
            }

            Spacer()
                .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: session.banner)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: session.meters > session.bestAtStart)
    }
}

// MARK: - Overlays

private struct Dim: View {
    var body: some View {
        Color.black.opacity(0.45).ignoresSafeArea()
    }
}

struct PauseOverlay: View {
    @ObservedObject var session: GameSession
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            Dim()
            VStack(spacing: 16) {
                Text("PAUSED")
                    .font(Theme.font(40))
                    .foregroundColor(.white)
                Button("RESUME") { session.resume() }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.grass, fontSize: 26))
                Button("END RUN") {
                    session.quit()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.pink, fontSize: 18))
            }
            .padding(.horizontal, 48)
        }
        .transition(.opacity)
    }
}

struct ReviveOverlay: View {
    @ObservedObject var session: GameSession

    var body: some View {
        ZStack {
            Dim()
            Card {
                VStack(spacing: 14) {
                    Text(session.reviveVariant.headline)
                        .font(Theme.font(28))
                        .foregroundColor(Theme.ink)
                        .multilineTextAlignment(.center)
                    ZStack {
                        Circle()
                            .stroke(Theme.ink.opacity(0.1), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: CGFloat(session.reviveSecondsLeft) / CGFloat(session.reviveVariant.countdownSeconds))
                            .stroke(Theme.grass, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: session.reviveSecondsLeft)
                        Text("\(session.reviveSecondsLeft)")
                            .font(Theme.font(40))
                            .foregroundColor(Theme.ink)
                    }
                    .frame(width: 110, height: 110)
                    if session.reviveVariant == .relaxed {
                        Text("You're at \(session.meters) m with \(session.hay) hay bales. One revive per run.")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.ink.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        session.acceptRevive()
                    } label: {
                        Label("Watch ad to revive", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.grass, fontSize: 20))
                    Button("No thanks") { session.declineRevive() }
                        .font(Theme.font(17))
                        .foregroundColor(Theme.ink.opacity(0.6))
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 32)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }
}

struct AdPlaceholderOverlay: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().tint(.white).scaleEffect(1.6)
                Text("Rewarded ad placeholder")
                    .font(Theme.font(18))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct GameOverOverlay: View {
    @ObservedObject var session: GameSession
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: GameStore
    @State private var appeared = false

    var body: some View {
        ZStack {
            Dim()
            VStack(spacing: 18) {
                Text("RUN OVER")
                    .font(Theme.font(42))
                    .foregroundColor(.white)
                    .shadow(color: Theme.ink, radius: 0, x: 0, y: 4)

                Card {
                    VStack(spacing: 10) {
                        if session.isNewBest {
                            Text("NEW BEST!")
                                .font(Theme.font(18))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Theme.pink))
                                .scaleEffect(appeared ? 1 : 0.3)
                        }
                        Text("\(session.meters) m")
                            .font(Theme.font(52))
                            .foregroundColor(Theme.ink)
                        Text("Reached \(session.biomeName)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.ink.opacity(0.6))
                        HStack(spacing: 8) {
                            Image(uiImage: HorseImages.hayIcon)
                                .resizable()
                                .frame(width: 28, height: 28)
                            Text("+\(session.hay)")
                                .font(Theme.font(24))
                                .foregroundColor(Theme.orange)
                            Text("Total \(store.hayBales)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.ink.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Button("RUN AGAIN") { app.play() }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.grass, fontSize: 26))
                HStack(spacing: 12) {
                    Button("Menu") { app.show(.menu) }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.orange, fontSize: 18))
                    Button("Scores") { app.show(.highScores) }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.purple, fontSize: 18))
                }
            }
            .padding(.horizontal, 32)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.15)) { appeared = true }
            if session.isNewBest { Haptics.shared.success() }
        }
    }
}
