import SwiftUI

enum Theme {
    static let sun = Color(red: 1.0, green: 0.80, blue: 0.10)
    static let grass = Color(red: 0.36, green: 0.80, blue: 0.20)
    static let orange = Color(red: 1.0, green: 0.48, blue: 0.10)
    static let pink = Color(red: 1.0, green: 0.30, blue: 0.55)
    static let purple = Color(red: 0.49, green: 0.30, blue: 1.0)
    static let sky = Color(red: 0.16, green: 0.66, blue: 0.96)
    static let ink = Color(red: 0.13, green: 0.09, blue: 0.16)

    static func font(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static let skyGradient = LinearGradient(
        colors: [Color(red: 0.16, green: 0.62, blue: 0.98), Color(red: 0.55, green: 0.86, blue: 1.0)],
        startPoint: .top, endPoint: .bottom)
}

/// Chunky, tactile button: drops into its shadow and ticks on touch-down.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color
    var fontSize: CGFloat = 22
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(Theme.font(fontSize))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 2)
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 3)
                            .padding(3)))
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(color)
                    .brightness(-0.28)
                    .offset(y: pressed ? 2 : 6))
            .offset(y: pressed ? 4 : 0)
            .animation(.spring(response: 0.16, dampingFraction: 0.6), value: pressed)
            .onChange(of: pressed) { isDown in
                if isDown { Haptics.shared.tap() }
            }
    }
}

struct HayBadge: View {
    let count: Int
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: 6) {
            Image(uiImage: HorseImages.hayIcon)
                .resizable()
                .frame(width: size * 1.3, height: size * 1.3)
            Text("\(count)")
                .font(Theme.font(size))
                .foregroundColor(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.28)))
    }
}

struct HorseRunView: View {
    let skin: Skin
    var width: CGFloat = 140
    var animated = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.09)) { context in
            let frame = animated ? Int(context.date.timeIntervalSinceReferenceDate / 0.09) % 4 : 0
            Image(uiImage: HorseImages.frame(skin, frame))
                .resizable()
                .scaledToFit()
                .frame(width: width, height: width * 1.25)
        }
    }
}

/// Shared header for the secondary screens.
struct ScreenHeader: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: GameStore
    let title: String

    var body: some View {
        HStack {
            Button {
                app.show(.menu)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.orange, fontSize: 20, fullWidth: false))
            Spacer()
            Text(title)
                .font(Theme.font(28))
                .foregroundColor(.white)
                .shadow(color: Theme.ink.opacity(0.4), radius: 0, x: 0, y: 3)
            Spacer()
            HayBadge(count: store.hayBales, size: 16)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct Card<Content: View>: View {
    var color: Color = .white
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(color)
                    .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 5))
    }
}
