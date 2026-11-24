import AppKit
import SwiftUI

public extension Color {
    /// Opaque sRGB colour from `0xRRGGBB`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Parses `#RRGGBB` or `RRGGBB`; nil for anything else.
    init?(hexString: String?) {
        guard let hexString else { return nil }
        var text = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(hex: value)
    }

    /// A colour that follows the appearance (light, dark and their
    /// Increase Contrast variants).
    static func adaptive(
        light: UInt32,
        dark: UInt32,
        lightHighContrast: UInt32? = nil,
        darkHighContrast: UInt32? = nil
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [
                .aqua, .darkAqua,
                .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
                .vibrantLight, .vibrantDark
            ])
            let value: UInt32
            switch match {
            case .darkAqua?, .vibrantDark?: value = dark
            case .accessibilityHighContrastDarkAqua?: value = darkHighContrast ?? dark
            case .accessibilityHighContrastAqua?: value = lightHighContrast ?? light
            default: value = light
            }
            return NSColor(
                srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// The Yatagarasu kit's fixed colours (`tokens/colors.json`,
/// `tokens/shikiban.json`). Use these on brand surfaces only; ordinary
/// window content uses `BrandColor`, which follows the appearance.
public enum BrandPalette {
    public static let ink = Color(hex: 0x120A2E)
    public static let night = Color(hex: 0x1A0E3E)
    public static let plum = Color(hex: 0x3A1060)
    public static let pink = Color(hex: 0xE6006F)
    public static let pinkActive = Color(hex: 0xD6006A)
    public static let pinkPressed = Color(hex: 0xA8005A)
    public static let pinkText = Color(hex: 0xFF4FA3)
    public static let ember = Color(hex: 0xFF7A1A)
    public static let gold = Color(hex: 0xFFC24A)
    public static let mint = Color(hex: 0x4FF0B8)
    public static let cyan = Color(hex: 0x38E8E0)
    public static let failure = Color(hex: 0xFF5A4D)
    public static let text = Color(hex: 0xFAF6FF)
    public static let textSoft = Color(hex: 0xE9E2F5)
    public static let textMuted = Color(hex: 0xCFC4E6)
    public static let line = Color(hex: 0x76618E)

    /// Shikiban stroke colours.
    public static let sealCore = Color(hex: 0xFFD58A)
    public static let sealGlow = Color(hex: 0xFF8A42)
    public static let sealStar = Color(hex: 0xFFE9BE)

    /// The app icon's radial gradient (`appIconGradient`).
    public static func iconGradient(diameter: CGFloat) -> RadialGradient {
        RadialGradient(
            stops: [
                .init(color: Color(hex: 0xFF7A2E), location: 0),
                .init(color: Color(hex: 0xE0126E), location: 0.3),
                .init(color: Color(hex: 0x4A1160), location: 0.66),
                .init(color: Color(hex: 0x120A2E), location: 1)
            ],
            center: UnitPoint(x: 0.5, y: 0.42),
            startRadius: 0,
            endRadius: diameter * 0.74
        )
    }
}

/// Colours for ordinary window content. Each one follows light and dark
/// appearance and keeps at least 4.5:1 against the window background.
public enum BrandColor {
    /// Brand text, selection and accent edges. Pink is for primary actions
    /// and active navigation only.
    public static let accent = Color.adaptive(light: 0xC2005F, dark: 0xFF4FA3, lightHighContrast: 0x8F0046, darkHighContrast: 0xFF8CC4)
    /// Fill of the primary button; white labels read 5.2:1 on it.
    public static let accentFill = Color(hex: 0xD6006A)
    public static let accentFillPressed = Color(hex: 0xA8005A)
    /// Price up and "in flight".
    public static let gain = Color.adaptive(light: 0x00706C, dark: 0x38E8E0, lightHighContrast: 0x004F4C, darkHighContrast: 0x7DF5EF)
    /// Price down.
    public static let loss = Color.adaptive(light: 0xB93A0B, dark: 0xFF8A3D, lightHighContrast: 0x8A2A06, darkHighContrast: 0xFFB27A)
    /// Final, confirmed, backed up.
    public static let final = Color.adaptive(light: 0x8A5A00, dark: 0xFFC24A, lightHighContrast: 0x5F3E00, darkHighContrast: 0xFFD98A)
    /// Needs attention (backup warnings, testnets).
    public static let warning = Color.adaptive(light: 0x9A5B00, dark: 0xFFB13D, lightHighContrast: 0x6B3F00, darkHighContrast: 0xFFCE85)
    /// Failed, rejected, destructive.
    public static let failure = Color.adaptive(light: 0xC2261A, dark: 0xFF6A5E, lightHighContrast: 0x8E180F, darkHighContrast: 0xFF9D95)
    /// Work in flight (pending transfers, syncing).
    public static let inFlight = Color.adaptive(light: 0x00706C, dark: 0x38E8E0, lightHighContrast: 0x004F4C, darkHighContrast: 0x7DF5EF)
    /// Card surface on top of the window background.
    public static let card = Color.adaptive(light: 0xFFFFFF, dark: 0x25242B)
    /// One-pixel separators and card rims.
    public static let hairline = Color(nsColor: .separatorColor)
}
