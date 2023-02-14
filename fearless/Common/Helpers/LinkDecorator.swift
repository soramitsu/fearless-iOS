import Foundation
import UIKit

protocol LinkDecoratorProtocol {
    func links(in attributedString: inout NSAttributedString) -> [(URL, NSRange)]
}

final class LinkDecorator: LinkDecoratorProtocol {
    private let pattern: String
    private let urls: [URL]
    private let linkColor: UIColor

    init(pattern: String, urls: [URL], linkColor: UIColor) {
        self.pattern = pattern
        self.urls = urls
        self.linkColor = linkColor
    }

    func links(in attributedString: inout NSAttributedString) -> [(URL, NSRange)] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var text = attributedString.string
        let range = NSRange(location: 0, length: text.utf16.count)
        let results = regex.matches(in: text, options: [], range: range)
        var links: [(URL, NSRange)] = []
        for result in results.enumerated() {
            let locationAfterRemovingPercents = result.element.range.location - 2 * 2 * result.offset
            let lengthAfterRemovingPercents = result.element.range.length - 4
            let trimmedRange = NSRange(location: locationAfterRemovingPercents, length: lengthAfterRemovingPercents)
            links.append((urls[result.offset], trimmedRange))
        }
        let ranges = links.map { $0.1 }
        text = text.replacingOccurrences(of: "%%", with: "")
        attributedString = addLinkAttribute(in: text, ranges: ranges)

        return links
    }

    private func addLinkAttribute(in text: String, ranges: [NSRange]) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttributes(
            [
                NSAttributedString.Key.font: UIFont.p1Paragraph,
                NSAttributedString.Key.foregroundColor: R.color.colorWhite50()! as Any
            ],
            range: NSRange(location: 0, length: text.count)
        )
        ranges.forEach { range in
            attributedString.addAttributes(
                [NSAttributedString.Key.foregroundColor: linkColor as Any],
                range: range
            )
        }
        return attributedString
    }
}

enum LinkDecoratorFactory {
    static func disclaimerDecorator() -> LinkDecorator {
        let pattern = "(%%.*?%%)" // detects substrings like %%Polkaswap FAQ%%
        let urls = [URL(string: "https://wiki.sora.org/polkaswap/polkaswap-faq")!,
                    URL(string: "https://wiki.sora.org/polkaswap/terms")!,
                    URL(string: "https://wiki.sora.org/polkaswap/privacy")!]

        return LinkDecorator(pattern: pattern, urls: urls, linkColor: R.color.colorPink()!)
    }
}
