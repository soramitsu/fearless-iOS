import AppKit
import SwiftUI

/// Bundled chain glyphs (white SVGs from
/// `remote-config/production/icons/chains/white/`) and coloured token icons
/// (`icons/tokens/coloured/`). Lookups ignore case; images are cached.
@MainActor
public enum IconLibrary {
    private static let chainIndex = DesignSystemResources.index(of: "Icons/chains", withExtension: "svg")
    private static let tokenIndex = DesignSystemResources.index(of: "Icons/tokens", withExtension: "svg")
    private static var chainCache: [String: NSImage] = [:]
    private static var tokenCache: [String: NSImage] = [:]

    /// Glyphs drawn as a filled disc with the mark cut out, and how much to
    /// enlarge them so the disc fills the icon slot.
    private static let discGlyphs: [String: CGFloat] = [
        "ethereum": 1.0,
        "eth": 1.0,
        "polygon": 1.0,
        "assethub": 1.2
    ]

    /// White template glyph for a chain icon name (the contract's `iconName`).
    public static func chainGlyph(named name: String?) -> NSImage? {
        guard let key = name?.lowercased(), !key.isEmpty else { return nil }
        if let cached = chainCache[key] { return cached }
        guard let url = chainIndex[key], let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        chainCache[key] = image
        return image
    }

    /// Scale for glyphs that are a full disc with the mark cut out; nil for plain glyphs.
    public static func discScale(named name: String?) -> CGFloat? {
        guard let key = name?.lowercased() else { return nil }
        return discGlyphs[key]
    }

    /// Full-colour token icon by file stem (the contract's `tokenIconName`,
    /// which for the bundled icons equals the ticker symbol).
    public static func tokenIcon(named name: String?) -> NSImage? {
        guard let key = name?.lowercased() else { return nil }
        guard !key.isEmpty else { return nil }
        if let cached = tokenCache[key] { return cached }
        guard let url = tokenIndex[key], let image = NSImage(contentsOf: url) else { return nil }
        tokenCache[key] = image
        return image
    }

    /// Brand colour for a chain when the catalog gives none.
    public static func fallbackAccent(iconName: String?, name: String) -> Color {
        switch (iconName ?? name).lowercased() {
        case "polkadot": return Color(hex: 0xE6007A)
        case "kusama": return Color(hex: 0x26262B)
        case "westend": return Color(hex: 0xDA68A7)
        case "assethub", "statemine": return Color(hex: 0x4B2A7B)
        case "ethereum", "eth": return Color(hex: 0x627EEA)
        case "bnbchain": return Color(hex: 0xC99400)
        case "polygon": return Color(hex: 0x8247E5)
        default: return monogramColor(for: name)
        }
    }

    /// Stable colour for a monogram disc, derived from the name.
    public static func monogramColor(for name: String) -> Color {
        var hash: UInt32 = 2_166_136_261
        for byte in name.lowercased().utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        let hue = Double(hash % 360) / 360
        return Color(hue: hue, saturation: 0.55, brightness: 0.62)
    }
}

/// Keeps a glyph visible on its disc whatever colour the catalog gives.
public enum IconContrast {
    /// Above this relative luminance a disc is too pale for a white glyph.
    public static let paleThreshold = 0.6

    /// WCAG relative luminance (0 black … 1 white) of `#RRGGBB`; nil for anything else.
    public static func relativeLuminance(hex: String?) -> Double? {
        guard var text = hex?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        func channel(_ shift: UInt32) -> Double {
            let c = Double((value >> shift) & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    /// True when a white glyph would not read on a disc of this colour.
    public static func needsDarkGlyph(accentHex: String?) -> Bool {
        guard let luminance = relativeLuminance(hex: accentHex) else { return false }
        return luminance > paleThreshold
    }

    /// The glyph colour for a disc: white, or ink on a pale disc.
    public static func glyphColor(accentHex: String?) -> Color {
        needsDarkGlyph(accentHex: accentHex) ? BrandPalette.ink : .white
    }

    /// Contrast ratio between the glyph colour chosen for a disc and the disc.
    public static func glyphContrast(accentHex: String?) -> Double? {
        guard let disc = relativeLuminance(hex: accentHex) else { return nil }
        let glyph = needsDarkGlyph(accentHex: accentHex) ? (relativeLuminance(hex: "#120A2E") ?? 0) : 1.0
        let lighter = max(disc, glyph)
        let darker = min(disc, glyph)
        return (lighter + 0.05) / (darker + 0.05)
    }
}
