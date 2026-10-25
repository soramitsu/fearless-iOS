import UIKit

extension UIFont {
    /// Compatibility roles retain Sora and their existing sizes until each legacy screen is rebuilt.
    /// Unlike generated forced unwraps, an unavailable resource remains a readable system font.
    static func legacySora(
        size: CGFloat, weight: UIFont.Weight,
        textStyle: UIFont.TextStyle? = nil,
        compatibleWith traits: UITraitCollection? = nil, boldText: Bool? = nil
    ) -> UIFont {
        let traits = traits ?? .current
        let bold = boldText ?? (traits.legibilityWeight == .bold || UIAccessibility.isBoldTextEnabled)
        let name: String
        let fallbackWeight: UIFont.Weight
        switch weight {
        case .bold, .heavy, .black:
            name = bold || weight != .bold ? "Sora-ExtraBold" : "Sora-Bold"
            fallbackWeight = bold ? .heavy : weight
        case .semibold, .medium:
            name = bold ? "Sora-Bold" : "Sora-SemiBold"
            fallbackWeight = bold ? .bold : .semibold
        default:
            name = bold ? "Sora-SemiBold" : "Sora-Regular"
            fallbackWeight = bold ? .semibold : .regular
        }
        let font = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: fallbackWeight)
        guard let textStyle else { return font }
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font, compatibleWith: traits)
    }

    static var h1Title: UIFont {
        legacySora(size: 30, weight: .bold, textStyle: .largeTitle)
    }

    static var h2Title: UIFont {
        legacySora(size: 22, weight: .bold, textStyle: .title2)
    }

    static var h3Title: UIFont {
        legacySora(size: 18, weight: .bold, textStyle: .title3)
    }

    static var h4Title: UIFont {
        legacySora(size: 16, weight: .bold, textStyle: .headline)
    }

    static var h5Title: UIFont {
        legacySora(size: 14, weight: .bold, textStyle: .subheadline)
    }

    static var h6Title: UIFont {
        legacySora(size: 12, weight: .bold, textStyle: .footnote)
    }

    static var capsTitle: UIFont {
        legacySora(size: 12, weight: .bold, textStyle: .caption1)
    }

    static var p0Paragraph: UIFont {
        legacySora(size: 16, weight: .regular, textStyle: .body)
    }

    static var p0Digits: UIFont {
        let features = [
            [UIFontDescriptor.FeatureKey.featureIdentifier: kNumberSpacingType,
             UIFontDescriptor.FeatureKey.typeIdentifier: kMonospacedNumbersSelector],
            [UIFontDescriptor.FeatureKey.featureIdentifier: kNumberCaseType,
             UIFontDescriptor.FeatureKey.typeIdentifier: kUpperCaseNumbersSelector]
        ]
        let font = legacySora(size: 16, weight: .regular, textStyle: .body)
        let descriptor = font.fontDescriptor.addingAttributes([.featureSettings: features])
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    static var p1Paragraph: UIFont {
        legacySora(size: 14, weight: .regular, textStyle: .callout)
    }

    static var p2Paragraph: UIFont {
        legacySora(size: 12, weight: .regular, textStyle: .footnote)
    }

    static var p3Paragraph: UIFont {
        legacySora(size: 12, weight: .semibold, textStyle: .caption1)
    }
}
