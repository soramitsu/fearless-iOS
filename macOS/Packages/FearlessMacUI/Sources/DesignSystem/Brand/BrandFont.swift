import AppKit
import CoreText
import SwiftUI

/// Figtree (SIL Open Font License 1.1, bundled with its licence) is the
/// brand's interface face. On the Mac it is used for display text only:
/// large balances, screen titles and brand moments. Body text, tables and
/// controls stay in the system font so the app reads as a native Mac app.
public enum BrandFont {
    public enum Weight: String, CaseIterable, Sendable {
        case regular = "figtree-400"
        case medium = "figtree-500"
        case semibold = "figtree-600"
        case bold = "figtree-700"

        var fallback: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }
    }

    /// PostScript names of the faces that registered, by weight. Evaluated
    /// once; registration is process-wide and needs no Info.plist entry.
    private static let registered: [Weight: String] = {
        var names: [Weight: String] = [:]
        for weight in Weight.allCases {
            guard let url = DesignSystemResources.url(forResource: weight.rawValue, withExtension: "ttf", subdirectory: "Fonts") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
               let first = descriptors.first,
               let name = CTFontDescriptorCopyAttribute(first, kCTFontNameAttribute) as? String {
                names[weight] = name
            }
        }
        return names
    }()

    /// Registers the bundled faces. Safe to call more than once.
    public static func registerIfNeeded() {
        _ = registered
    }

    /// True when the bundled face for `weight` is available.
    public static func isAvailable(_ weight: Weight) -> Bool {
        registered[weight] != nil
    }

    /// Display face at a fixed size; falls back to the rounded-free system
    /// font if the bundled file is missing.
    public static func display(_ size: CGFloat, weight: Weight = .bold) -> Font {
        if let name = registered[weight] {
            return Font.custom(name, fixedSize: size)
        }
        return Font.system(size: size, weight: weight.fallback)
    }

    /// The licence text shipped with the fonts, for the acknowledgements.
    public static var licenceText: String? {
        guard let url = DesignSystemResources.url(forResource: "Figtree-LICENSE", withExtension: "txt", subdirectory: "Fonts") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

public extension Font {
    /// Brand display text (Figtree).
    static func brandDisplay(_ size: CGFloat, weight: BrandFont.Weight = .bold) -> Font {
        BrandFont.display(size, weight: weight)
    }
}
