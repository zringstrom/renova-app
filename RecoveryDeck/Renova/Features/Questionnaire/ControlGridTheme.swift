import SwiftUI

/// Colors and type ported 1:1 from the approved `questionnaire-v5.html` mockup
/// ("Control Grid" — Swiss control-room aesthetic).
enum CGTheme {
    static let bg = Color.dynamic(light: 0xE2E2DE, dark: 0x151513)
    static let surface = Color.dynamic(light: 0xFBFBF9, dark: 0x1C1C19)
    static let surface2 = Color.dynamic(light: 0xF0F0EC, dark: 0x232320)
    static let line = Color.dynamic(light: 0xD2D2CB, dark: 0x33332E)
    static let lineStrong = Color.dynamic(light: 0xADADA2, dark: 0x48483F)
    static let ink = Color.dynamic(light: 0x0A0A08, dark: 0xF2F2EC)
    static let inkDim = Color.dynamic(light: 0x5F5F57, dark: 0xADADA2)
    static let inkFaint = Color.dynamic(light: 0x8F8F84, dark: 0x75756A)
    static let accent = Color.dynamic(light: 0xE8331B, dark: 0xFF5A3D)
    static let accent2 = Color.dynamic(light: 0x1B6E5C, dark: 0x3DDCB8)

    // Status trio — CVD-validated. NEVER shown without an accompanying direction
    // label (PRD §6.6 requires labeled direction anyway).
    static let statusOk = Color.dynamic(light: 0x0F7A5C, dark: 0x3DDCB8)     // inside ±1 SD band
    static let statusWatch = Color.dynamic(light: 0xD4A017, dark: 0xE3B341) // 1–1.5 SD out
    static let statusAlert = Color.dynamic(light: 0xE8331B, dark: 0xFF5A3D) // >1.5 SD out (== accent)

    static let mono: Font = .system(.footnote, design: .monospaced)
    static let monoSmall: Font = .system(size: 10, weight: .regular, design: .monospaced)
    static let sectionLabel: Font = .system(size: 11, weight: .semibold, design: .monospaced)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            UIColor(trait.userInterfaceStyle == .dark ? Color(hex: dark) : Color(hex: light))
        })
    }
}
