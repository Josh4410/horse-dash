import SwiftUI

@main
struct HorseDashApp: App {
    @StateObject private var app = AppModel()
    @StateObject private var store = GameStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(store)
                .preferredColorScheme(.light)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

final class AppModel: ObservableObject {
    enum Screen {
        case menu, game, highScores, store, settings
    }

    @Published private(set) var screen: Screen = .menu
    @Published private(set) var session: GameSession?

    func play() {
        session = GameSession(size: UIScreen.main.bounds.size)
        screen = .game
    }

    func show(_ screen: Screen) {
        if screen != .game { session = nil }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            self.screen = screen
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            switch app.screen {
            case .menu:
                MainMenuView().transition(.opacity)
            case .game:
                if let session = app.session {
                    GameScreen(session: session)
                        .id(ObjectIdentifier(session))
                        .transition(.opacity)
                }
            case .highScores:
                HighScoresView().transition(.move(edge: .trailing))
            case .store:
                SkinsStoreView().transition(.move(edge: .trailing))
            case .settings:
                SettingsView().transition(.move(edge: .trailing))
            }
        }
        .onAppear {
            Haptics.shared.prepare()
            Analytics.shared.log("app_open")
        }
    }
}
