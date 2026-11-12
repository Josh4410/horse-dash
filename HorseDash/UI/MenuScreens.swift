import SwiftUI

// MARK: - High scores

struct HighScoresView: View {
    @EnvironmentObject private var store: GameStore

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.purple, Theme.pink], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ScreenHeader(title: "High Scores")
                if store.highScores.isEmpty {
                    Spacer()
                    Card {
                        VStack(spacing: 8) {
                            Text("No runs yet")
                                .font(Theme.font(24))
                                .foregroundColor(Theme.ink)
                            Text("Hit Play and see how far you can gallop.")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.ink.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 24)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(Array(store.highScores.enumerated()), id: \.element.id) { index, entry in
                                row(rank: index + 1, entry: entry)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    private func medal(_ rank: Int) -> Color {
        switch rank {
        case 1: return Theme.sun
        case 2: return Color(white: 0.78)
        case 3: return Color(red: 0.85, green: 0.5, blue: 0.2)
        default: return Theme.sky
        }
    }

    private func row(rank: Int, entry: ScoreEntry) -> some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(Theme.font(20))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(medal(rank)))
                .overlay(Circle().stroke(Theme.ink.opacity(0.2), lineWidth: 3))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.meters) m")
                    .font(Theme.font(24))
                    .foregroundColor(Theme.ink)
                Text("\(entry.biome)  ·  \(Self.dateFormat.string(from: entry.date))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.ink.opacity(0.55))
            }
            Spacer()
            HStack(spacing: 4) {
                Image(uiImage: HorseImages.hayIcon)
                    .resizable()
                    .frame(width: 22, height: 22)
                Text("\(entry.hay)")
                    .font(Theme.font(18))
                    .foregroundColor(Theme.orange)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 4))
    }
}

// MARK: - Skins store

struct SkinsStoreView: View {
    @EnvironmentObject private var store: GameStore
    @State private var pending: Skin?
    @State private var shakeID: String?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.pink, Theme.orange], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ScreenHeader(title: "Skins")
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Skins.all) { skin in
                            tile(skin)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .alert(item: $pending) { skin in
            Alert(
                title: Text("Buy \(skin.name)?"),
                message: Text("Costs \(skin.price) hay bales."),
                primaryButton: .default(Text("Buy")) { buy(skin) },
                secondaryButton: .cancel())
        }
    }

    private func tile(_ skin: Skin) -> some View {
        let owned = store.owns(skin)
        let selected = store.selectedSkin == skin.id
        return Button {
            tapped(skin)
        } label: {
            VStack(spacing: 8) {
                HorseRunView(skin: skin, width: 84, animated: selected)
                    .padding(.top, 6)
                Text(skin.name)
                    .font(Theme.font(16))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Group {
                    if selected {
                        Text("RIDING")
                    } else if owned {
                        Text("SELECT")
                    } else {
                        HStack(spacing: 4) {
                            Image(uiImage: HorseImages.hayIcon)
                                .resizable()
                                .frame(width: 18, height: 18)
                            Text("\(skin.price)")
                        }
                    }
                }
                .font(Theme.font(15))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Theme.grass : owned ? Theme.sky : (store.hayBales >= skin.price ? Theme.orange : Color.gray)))
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(selected ? Theme.grass : .clear, lineWidth: 4))
                    .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 5))
            .modifier(Shake(animatableData: shakeID == skin.id ? 1 : 0))
        }
        .buttonStyle(.plain)
    }

    private func tapped(_ skin: Skin) {
        if store.owns(skin) {
            Haptics.shared.tap()
            store.selectedSkin = skin.id
        } else if store.hayBales >= skin.price {
            Haptics.shared.tap()
            pending = skin
        } else {
            Haptics.shared.error()
            withAnimation(.linear(duration: 0.35)) { shakeID = skin.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shakeID = nil }
        }
    }

    private func buy(_ skin: Skin) {
        switch store.buy(skin) {
        case .purchased: Haptics.shared.success()
        case .alreadyOwned: break
        case .insufficientFunds: Haptics.shared.error()
        }
    }
}

private struct Shake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 6), y: 0))
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var store: GameStore
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.sky, Theme.purple], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ScreenHeader(title: "Settings")
                ScrollView {
                    VStack(spacing: 14) {
                        Card {
                            VStack(spacing: 4) {
                                toggle("Vibration", icon: "iphone.radiowaves.left.and.right", isOn: $store.settings.vibration)
                                toggle("Music", icon: "music.note", isOn: $store.settings.music)
                                toggle("Sound effects", icon: "speaker.wave.2.fill", isOn: $store.settings.soundEffects)
                                toggle("Reduce camera shake", icon: "camera.metering.unknown", isOn: $store.settings.reduceCameraShake)
                            }
                        }
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                toggle("Dynamic difficulty", icon: "dial.medium.fill", isOn: $store.settings.dynamicDifficulty)
                                Text("Gives a little more room between obstacles after a few short runs, and a little less after very long ones. Based only on your recent run lengths.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(Theme.ink.opacity(0.6))
                            }
                        }
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                toggle("Share analytics", icon: "chart.bar.fill", isOn: $store.settings.analytics)
                                Text("When on, we collect:")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.ink.opacity(0.7))
                                ForEach(Analytics.collectedFields, id: \.self) { field in
                                    Text("• \(field)")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(Theme.ink.opacity(0.6))
                                }
                                Text("Revive prompt test group: \(ReviveExperiment.variant.label)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(Theme.ink.opacity(0.6))
                                    .padding(.top, 4)
                            }
                        }
                        Button("Reset progress") { confirmReset = true }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.pink, fontSize: 18))
                        Text("Horse Dash \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .onChange(of: store.settings.vibration) { on in
            if on { Haptics.shared.preview() }
        }
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset hay, scores and skins", role: .destructive) { store.resetProgress() }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func toggle(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label {
                Text(title)
                    .font(Theme.font(17))
                    .foregroundColor(Theme.ink)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(Theme.purple)
            }
        }
        .tint(Theme.grass)
        .padding(.vertical, 6)
    }
}
