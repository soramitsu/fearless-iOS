import Foundation
import UIKit

protocol PolkaswapDisclaimerViewModelFactoryProtocol {
    func buildViewModel(
        locale: Locale,
        delegate: TappedLabelDelegate?
    ) -> PolkaswapDisclaimerViewModel
}

final class PolkaswapDisclaimerViewModelFactory: PolkaswapDisclaimerViewModelFactoryProtocol {
    private lazy var linkDecorator: LinkDecorator = {
        LinkDecoratorFactory.disclaimerDecorator()
    }()

    func buildViewModel(
        locale: Locale,
        delegate: TappedLabelDelegate?
    ) -> PolkaswapDisclaimerViewModel {
        let firstParagraphText = R.string.localizable
            .polkaswapDisclaimerParagraph1(preferredLanguages: locale.rLanguages)
        let fourthParagraphText = R.string.localizable
            .polkaswapDisclaimerParagraph4(preferredLanguages: locale.rLanguages)
        let importantParagraphText = R.string.localizable
            .polkaswapDisclaimerImportant(preferredLanguages: locale.rLanguages)

        var firstParagraphAttributedString = NSAttributedString(string: firstParagraphText)
        var fourthParagraphAttributedString = NSAttributedString(string: fourthParagraphText)
        let importantParagraphAttributedString = addImportantAttribute(in: importantParagraphText)

        let firstParagraphLinks: [(URL, NSRange)] = linkDecorator.links(in: &firstParagraphAttributedString)
        let fourthParagraphTextLinks: [(URL, NSRange)] = linkDecorator.links(in: &fourthParagraphAttributedString)

        let viewModel = PolkaswapDisclaimerViewModel(
            firstParagraph: firstParagraphAttributedString,
            fourthParagraph: fourthParagraphAttributedString,
            importantParagraph: importantParagraphAttributedString,
            firstParagraphLinks: firstParagraphLinks,
            fourthParagraphLinks: fourthParagraphTextLinks,
            delegate: delegate
        )

        return viewModel
    }

    private func addImportantAttribute(in text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttributes(
            [
                NSAttributedString.Key.font: UIFont.p1Paragraph,
                NSAttributedString.Key.foregroundColor: R.color.colorWhite50()! as Any
            ],
            range: NSRange(location: 0, length: text.count)
        )
        attributedString.addAttributes(
            [NSAttributedString.Key.foregroundColor: R.color.colorOrange()! as Any],
            range: NSRange(location: 0, length: 10)
        )
        return attributedString
    }
}
