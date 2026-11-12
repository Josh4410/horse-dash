import Foundation

enum CoatPattern {
    case solid, socks, dapple, stripes, sparkle
}

struct Skin: Identifiable, Equatable {
    let id: String
    let name: String
    let price: Int
    let coat: RGB
    let mane: RGB
    let blanket: RGB
    let pattern: CoatPattern
}

enum Skins {
    static let defaultID = "chestnut"

    static let all: [Skin] = [
        Skin(id: "chestnut", name: "Chestnut", price: 0,
             coat: RGB(0xB5651D), mane: RGB(0x4E2A0E), blanket: RGB(0xE53935), pattern: .solid),
        Skin(id: "midnight", name: "Midnight", price: 300,
             coat: RGB(0x2B2D42), mane: RGB(0x111111), blanket: RGB(0x00B8D4), pattern: .socks),
        Skin(id: "palomino", name: "Palomino", price: 500,
             coat: RGB(0xF2B544), mane: RGB(0xFFF4D6), blanket: RGB(0x1E88E5), pattern: .solid),
        Skin(id: "dapple", name: "Dapple Grey", price: 800,
             coat: RGB(0xB0BEC5), mane: RGB(0x546E7A), blanket: RGB(0x8E24AA), pattern: .dapple),
        Skin(id: "bubblegum", name: "Bubblegum", price: 1200,
             coat: RGB(0xFF7EB6), mane: RGB(0x40C4FF), blanket: RGB(0xFFEB3B), pattern: .socks),
        Skin(id: "zebra", name: "Zig Zag", price: 1500,
             coat: RGB(0xF5F5F5), mane: RGB(0x212121), blanket: RGB(0xFF5252), pattern: .stripes),
        Skin(id: "lime", name: "Lime Rocket", price: 2000,
             coat: RGB(0x76FF03), mane: RGB(0x1B5E20), blanket: RGB(0xFF6D00), pattern: .solid),
        Skin(id: "gold", name: "Golden Champion", price: 3000,
             coat: RGB(0xFFC400), mane: RGB(0xFF6F00), blanket: RGB(0x6A1B9A), pattern: .sparkle),
        Skin(id: "galaxy", name: "Galaxy", price: 5000,
             coat: RGB(0x5E35B1), mane: RGB(0x18FFFF), blanket: RGB(0xFF4081), pattern: .sparkle),
    ]

    static func skin(id: String) -> Skin {
        all.first { $0.id == id } ?? all[0]
    }
}
