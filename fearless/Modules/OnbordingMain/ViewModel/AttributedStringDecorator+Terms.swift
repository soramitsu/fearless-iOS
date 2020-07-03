import UIKit

extension CompoundAttributedStringDecorator {
    static func legal(for locale: Locale?) -> AttributedStringDecoratorProtocol {
        let textColor = UIColor(red: 155.0 / 255.0, green: 155.0 / 255.0, blue: 155.0 / 255.0, alpha: 1.0)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: R.font.soraRc0040417Regular(size: 12)!
        ]

        let rangeDecorator = RangeAttributedStringDecorator(attributes: attributes)

        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSNumber(value: NSUnderlineStyle.single.rawValue)
        ]

        let termsConditions = R.string.localizable
            .onboardingTermsAndConditions2(preferredLanguages: locale?.rLanguages)
        let termDecorator = HighlightingAttributedStringDecorator(pattern: termsConditions,
                                                                           attributes: highlightAttributes)

        let privacyPolicy = R.string.localizable
            .onboardingPrivacyPolicy(preferredLanguages: locale?.rLanguages)
        let privacyDecorator = HighlightingAttributedStringDecorator(pattern: privacyPolicy,
                                                                     attributes: highlightAttributes)

        return CompoundAttributedStringDecorator(decorators: [rangeDecorator, termDecorator, privacyDecorator])
    }
}
