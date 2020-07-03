import UIKit

protocol AttributedStringDecoratorProtocol: class {
    func decorate(attributedString: NSAttributedString) -> NSAttributedString
}

final class HighlightingAttributedStringDecorator: AttributedStringDecoratorProtocol {
    let pattern: String
    let attributes: [NSAttributedString.Key: Any]

    init(pattern: String, attributes: [NSAttributedString.Key: Any]) {
        self.pattern = pattern
        self.attributes = attributes
    }

    func decorate(attributedString: NSAttributedString) -> NSAttributedString {
        let string = attributedString.string as NSString
        let range = string.range(of: pattern)

        guard
            range.location != NSNotFound,
            let resultAttributedString = attributedString.mutableCopy() as? NSMutableAttributedString else {
                return attributedString
        }

        resultAttributedString.addAttributes(attributes, range: range)

        return resultAttributedString
    }
}

final class RangeAttributedStringDecorator: AttributedStringDecoratorProtocol {
    let range: NSRange?
    let attributes: [NSAttributedString.Key: Any]

    init(attributes: [NSAttributedString.Key: Any], range: NSRange? = nil) {
        self.range = range
        self.attributes = attributes
    }

    func decorate(attributedString: NSAttributedString) -> NSAttributedString {
        let applicationRange = range ?? NSRange(location: 0, length: attributedString.length)

        guard let resultAttributedString = attributedString.mutableCopy() as? NSMutableAttributedString else {
            return attributedString
        }

        resultAttributedString.addAttributes(attributes, range: applicationRange)
        return resultAttributedString
    }
}

final class CompoundAttributedStringDecorator: AttributedStringDecoratorProtocol {
    let decorators: [AttributedStringDecoratorProtocol]

    init(decorators: [AttributedStringDecoratorProtocol]) {
        self.decorators = decorators
    }

    func decorate(attributedString: NSAttributedString) -> NSAttributedString {
        return decorators.reduce(attributedString) { (result, decorator) in
            return decorator.decorate(attributedString: result)
        }
    }
}
