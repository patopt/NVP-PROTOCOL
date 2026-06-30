import SwiftUI

/// An app tile in NVP OS. `native` embeds an existing NVP SwiftUI screen; `web`
/// opens a service's web version in-app; `soon` shows the Apple-restriction note.
struct OSApp: Identifiable {
    let id: String
    let name: String
    let icon: String          // SF Symbol
    let colors: [Color]       // icon gradient
    let kind: Kind

    enum Kind {
        case native(String)   // internal screen id
        case web(String)      // URL string
        case soon
    }

    static var catalog: [OSApp] {
        let base = Config.coordinatorURL
        return [
            // Dock (first 4)
            OSApp(id: "worker", name: "Worker", icon: "bolt.fill", colors: [Color(hex: 0x6e8bff), Color(hex: 0x9b6bff)], kind: .native("worker")),
            OSApp(id: "chat", name: "Chat NVP", icon: "bubble.left.and.bubble.right.fill", colors: [Color(hex: 0x22d3ee), Color(hex: 0x3b82f6)], kind: .web(base + "/chat")),
            OSApp(id: "wallet", name: "Wallet", icon: "wallet.pass.fill", colors: [Color(hex: 0x34c759), Color(hex: 0x16a34a)], kind: .native("wallet")),
            OSApp(id: "settings", name: "Réglages", icon: "gearshape.fill", colors: [Color(hex: 0x8b95a7), Color(hex: 0x5b6472)], kind: .native("settings")),

            // Grid
            OSApp(id: "studio", name: "Studio", icon: "wand.and.stars", colors: [Color(hex: 0x9b6bff), Color(hex: 0xe854d2)], kind: .web(base + "/studio")),
            OSApp(id: "network", name: "Réseau", icon: "point.3.connected.trianglepath.dotted", colors: [Color(hex: 0x06b6d4), Color(hex: 0x6366f1)], kind: .native("network")),
            OSApp(id: "earnings", name: "Gains", icon: "dollarsign.circle.fill", colors: [Color(hex: 0xf59e0b), Color(hex: 0xf97316)], kind: .native("earnings")),
            OSApp(id: "logs", name: "Logs", icon: "text.alignleft", colors: [Color(hex: 0x64748b), Color(hex: 0x334155)], kind: .native("logs")),
            OSApp(id: "youtube", name: "YouTube", icon: "play.rectangle.fill", colors: [Color(hex: 0xff3b30), Color(hex: 0xb91c1c)], kind: .web("https://m.youtube.com")),
            OSApp(id: "telegram", name: "Telegram", icon: "paperplane.fill", colors: [Color(hex: 0x2aabee), Color(hex: 0x1d6fa5)], kind: .web("https://web.telegram.org")),
            OSApp(id: "discord", name: "Discord", icon: "message.fill", colors: [Color(hex: 0x5865f2), Color(hex: 0x4044b3)], kind: .web("https://discord.com/app")),
            OSApp(id: "leaderboard", name: "Classement", icon: "trophy.fill", colors: [Color(hex: 0xfacc15), Color(hex: 0xca8a04)], kind: .web(base + "/leaderboard")),
            OSApp(id: "ig", name: "Instagram", icon: "camera.fill", colors: [Color(hex: 0xe1306c), Color(hex: 0xf77737)], kind: .soon),
            OSApp(id: "wa", name: "WhatsApp", icon: "phone.fill", colors: [Color(hex: 0x25d366), Color(hex: 0x128c7e)], kind: .soon),
            OSApp(id: "games", name: "Jeux", icon: "gamecontroller.fill", colors: [Color(hex: 0xa855f7), Color(hex: 0x7c3aed)], kind: .soon),
        ]
    }
}

extension Color {
    init(hex: Int) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
