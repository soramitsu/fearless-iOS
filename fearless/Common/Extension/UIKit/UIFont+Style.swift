import UIKit

extension UIFont {
    static var h1Title: UIFont { UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: R.font.soraRc0040417Bold(size: 30)!, compatibleWith: .current) }

    static var h2Title: UIFont { UIFontMetrics(forTextStyle: .title2).scaledFont(for: R.font.soraRc0040417Bold(size: 22)!, compatibleWith: .current) }

    static var h3Title: UIFont { UIFontMetrics(forTextStyle: .title3).scaledFont(for: R.font.soraRc0040417Bold(size: 18)!, compatibleWith: .current) }

    static var h4Title: UIFont { UIFontMetrics(forTextStyle: .headline).scaledFont(for: R.font.soraRc0040417Bold(size: 16)!, compatibleWith: .current) }

    static var h5Title: UIFont { UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: R.font.soraRc0040417Bold(size: 14)!, compatibleWith: .current) }

    static var h6Title: UIFont { UIFontMetrics(forTextStyle: .footnote).scaledFont(for: R.font.soraRc0040417Bold(size: 12)!, compatibleWith: .current) }

    static var capsTitle: UIFont { UIFontMetrics(forTextStyle: .caption1).scaledFont(for: R.font.soraRc0040417Bold(size: 12)!, compatibleWith: .current) }

    static var p0Paragraph: UIFont { UIFontMetrics(forTextStyle: .body).scaledFont(for: R.font.soraRc0040417Regular(size: 16)!, compatibleWith: .current) }

    static var p0Digits: UIFont {
        let fontFeatures = [
            [
                UIFontDescriptor.FeatureKey.featureIdentifier: kNumberSpacingType,
                UIFontDescriptor.FeatureKey.typeIdentifier: kMonospacedNumbersSelector
            ],

            [
                UIFontDescriptor.FeatureKey.featureIdentifier: kNumberCaseType,
                UIFontDescriptor.FeatureKey.typeIdentifier: kUpperCaseNumbersSelector
            ]
        ]

        let fontDescriptor = R.font.soraRc0040417Regular(size: 16)!.fontDescriptor
            .addingAttributes([UIFontDescriptor.AttributeName.featureSettings: fontFeatures])

        return UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont(descriptor: fontDescriptor, size: 16), compatibleWith: .current)
    }

    static var p1Paragraph: UIFont { UIFontMetrics(forTextStyle: .callout).scaledFont(for: R.font.soraRc0040417Regular(size: 14)!, compatibleWith: .current) }

    static var p2Paragraph: UIFont { UIFontMetrics(forTextStyle: .footnote).scaledFont(for: R.font.soraRc0040417Regular(size: 12)!, compatibleWith: .current) }

    static var p3Paragraph: UIFont { UIFontMetrics(forTextStyle: .caption1).scaledFont(for: R.font.soraRc0040417SemiBold(size: 12)!, compatibleWith: .current) }
}
