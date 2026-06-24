import SwiftUI

/// Shared NVP fintech identity (teal + lime), matching the iOS / Android apps.
enum Theme {
    static let bg = Color(red: 0.055, green: 0.122, blue: 0.102)     // #0E1F1A
    static let card = Color(red: 0.078, green: 0.204, blue: 0.169)   // #14342B
    static let card2 = Color(red: 0.110, green: 0.290, blue: 0.231)  // #1C4A3B
    static let teal = Color(red: 0.078, green: 0.227, blue: 0.196)   // #143A32
    static let accent = Color(red: 0.788, green: 0.949, blue: 0.306) // #C9F24E lime
    static let onAccent = Color(red: 0.055, green: 0.130, blue: 0.106)
    static let text = Color(red: 0.918, green: 0.953, blue: 0.933)   // #EAF3EE
    static let muted = Color(red: 0.616, green: 0.722, blue: 0.675)  // #9DB8AC
    static let green = Color(red: 0.310, green: 0.878, blue: 0.627)
    static let red = Color(red: 1.0, green: 0.42, blue: 0.42)
}

extension View {
    func nvpCard() -> some View {
        self.padding(18)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
