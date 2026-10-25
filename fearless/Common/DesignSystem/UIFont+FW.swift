import UIKit

enum FWFontStyle: CaseIterable {
    case displayXL, displayL, titleL, titleM, titleS
    case bodyL, bodyM, bodyS, labelL, labelM, labelS
    case numberL, numberM, numberS, hud, monoM, monoS, phraseWord

    fileprivate enum Face { case body, number, title, mono, hud }
    fileprivate struct Recipe {
        let size: CGFloat
        let line: CGFloat
        let weight: UIFont.Weight
        let metric: UIFont.TextStyle
        let face: Face
    }

    fileprivate var recipe: Recipe {
        switch self {
        case .displayXL: return Recipe(size: 40, line: 44, weight: .semibold, metric: .largeTitle, face: .number)
        case .displayL: return Recipe(size: 32, line: 38, weight: .semibold, metric: .title1, face: .number)
        case .titleL: return Recipe(size: 24, line: 30, weight: .semibold, metric: .title2, face: .title)
        case .titleM: return Recipe(size: 20, line: 26, weight: .semibold, metric: .title3, face: .title)
        case .titleS: return Recipe(size: 17, line: 22, weight: .semibold, metric: .headline, face: .body)
        case .bodyL: return Recipe(size: 17, line: 24, weight: .regular, metric: .body, face: .body)
        case .bodyM: return Recipe(size: 15, line: 22, weight: .regular, metric: .subheadline, face: .body)
        case .bodyS: return Recipe(size: 13, line: 18, weight: .regular, metric: .footnote, face: .body)
        case .labelL: return Recipe(size: 16, line: 20, weight: .semibold, metric: .headline, face: .body)
        case .labelM: return Recipe(size: 14, line: 20, weight: .semibold, metric: .subheadline, face: .body)
        case .labelS: return Recipe(size: 12, line: 16, weight: .semibold, metric: .caption1, face: .body)
        case .numberL: return Recipe(size: 17, line: 22, weight: .semibold, metric: .headline, face: .number)
        case .numberM: return Recipe(size: 15, line: 20, weight: .regular, metric: .subheadline, face: .number)
        case .numberS: return Recipe(size: 13, line: 18, weight: .regular, metric: .footnote, face: .number)
        case .hud: return Recipe(size: 12, line: 16, weight: .medium, metric: .caption1, face: .hud)
        case .monoM: return Recipe(size: 15, line: 22, weight: .regular, metric: .subheadline, face: .mono)
        case .monoS: return Recipe(size: 13, line: 18, weight: .regular, metric: .footnote, face: .mono)
        case .phraseWord: return Recipe(size: 17, line: 24, weight: .semibold, metric: .body, face: .body)
        }
    }
}

extension UIFont {
    /// Scaled fonts for rebuilt surfaces. Amounts always use SF Pro tabular figures.
    /// Bundled display and mono faces have a readable system fallback if unavailable.
    static func fw(
        _ style: FWFontStyle, locale: Locale = .current,
        compatibleWith traits: UITraitCollection? = nil, boldText: Bool? = nil
    ) -> UIFont {
        let recipe = style.recipe
        let bold = boldText ?? (traits?.legibilityWeight == .bold || UIAccessibility.isBoldTextEnabled)
        let weight: Weight = bold ? (recipe.weight == .regular ? .semibold : .bold) : recipe.weight
        let language = locale.languageCode ?? "en"
        let base: UIFont
        switch recipe.face {
        case .number:
            base = .monospacedDigitSystemFont(ofSize: recipe.size, weight: weight)
        case .title where ["en", "id", "pt", "tr"].contains(language):
            base = UIFont(name: bold ? "Sora-Bold" : "Sora-SemiBold", size: recipe.size)
                ?? .systemFont(ofSize: recipe.size, weight: weight)
        case .mono, .hud:
            if recipe.face == .hud, ["ja", "zh"].contains(language) {
                base = .systemFont(ofSize: recipe.size, weight: weight)
            } else {
                let medium = bold || recipe.face == .hud
                let mono = UIFont(name: medium ? "JetBrainsMono-Medium" : "JetBrainsMono-Regular", size: recipe.size)
                if bold, recipe.face == .hud, let descriptor = mono?.fontDescriptor.withSymbolicTraits(.traitBold) {
                    base = UIFont(descriptor: descriptor, size: recipe.size)
                } else {
                    let fallbackWeight: Weight = bold && recipe.face == .hud ? .semibold : (medium ? .medium : .regular)
                    base = mono ?? .monospacedSystemFont(ofSize: recipe.size, weight: fallbackWeight)
                }
            }
        default:
            base = .systemFont(ofSize: recipe.size, weight: weight)
        }
        return UIFontMetrics(forTextStyle: recipe.metric).scaledFont(for: base, compatibleWith: traits)
    }

    /// Minimum paragraph line height; never crop a platform fallback font's taller glyphs.
    static func fwLineHeight(
        _ style: FWFontStyle, calm: Bool = false, locale: Locale = .current,
        compatibleWith traits: UITraitCollection? = nil
    ) -> CGFloat {
        let recipe = style.recipe
        let line = style == .bodyL && calm ? 26 : recipe.line
        return max(
            fw(style, locale: locale, compatibleWith: traits).lineHeight,
            UIFontMetrics(forTextStyle: recipe.metric).scaledValue(for: line, compatibleWith: traits)
        )
    }
}
