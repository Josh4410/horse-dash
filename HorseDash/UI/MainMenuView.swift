import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: GameStore
    @State private var bounce = false

    var body: some View {
        ZStack {
            Theme.skyGradient.ignoresSafeArea()
            MenuBackdrop()

            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    HayBadge(count: store.hayBales)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 0)

                VStack(spacing: -6) {
                    Text("HORSE")
                    Text("DASH")
                }
                .font(Theme.font(64))
                .foregroundStyle(LinearGradient(colors: [Theme.sun, Theme.orange], startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.ink, radius: 0, x: 0, y: 5)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 8)
                .scaleEffect(bounce ? 1.04 : 0.98)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: bounce)

                HorseRunView(skin: Skins.skin(id: store.selectedSkin), width: 130)

                Text("BEST  \(store.best) m")
                    .font(Theme.font(20))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.ink.opacity(0.35)))

                Spacer(minLength: 0)

                VStack(spacing: 14) {
                    Button("PLAY") { app.play() }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.grass, fontSize: 34))
                    HStack(spacing: 12) {
                        Button {
                            app.show(.store)
                        } label: {
                            Label("Skins", systemImage: "paintpalette.fill")
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.pink, fontSize: 18))
                        Button {
                            app.show(.highScores)
                        } label: {
                            Label("Scores", systemImage: "trophy.fill")
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.purple, fontSize: 18))
                    }
                    Button {
                        app.show(.settings)
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.orange, fontSize: 18))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .onAppear { bounce = true }
    }
}

/// Rolling farm hills behind the menu.
private struct MenuBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Circle()
                    .fill(Color(red: 1, green: 0.95, blue: 0.45))
                    .frame(width: 120, height: 120)
                    .shadow(color: .yellow.opacity(0.7), radius: 30)
                    .position(x: geo.size.width * 0.8, y: geo.size.height * 0.16)
                Ellipse()
                    .fill(Color(red: 0.30, green: 0.73, blue: 0.27))
                    .frame(width: geo.size.width * 1.6, height: geo.size.height * 0.5)
                    .offset(x: -geo.size.width * 0.3, y: geo.size.height * 0.28)
                Ellipse()
                    .fill(Color(red: 0.49, green: 0.82, blue: 0.23))
                    .frame(width: geo.size.width * 1.5, height: geo.size.height * 0.45)
                    .offset(x: geo.size.width * 0.35, y: geo.size.height * 0.3)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .ignoresSafeArea()
    }
}
