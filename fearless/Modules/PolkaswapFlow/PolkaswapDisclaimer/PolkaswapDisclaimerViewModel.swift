import Foundation

struct PolkaswapDisclaimerViewModel {
    let firstParagraph: NSAttributedString
    let fourthParagraph: NSAttributedString
    let importantParagraph: NSAttributedString

    let firstParagraphLinks: [(URL, NSRange)]
    let fourthParagraphLinks: [(URL, NSRange)]

    let delegate: TappedLabelDelegate?
}
