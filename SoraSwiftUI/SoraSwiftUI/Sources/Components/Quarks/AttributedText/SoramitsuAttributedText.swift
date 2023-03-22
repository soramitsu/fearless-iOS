import UIKit

public protocol SoramitsuAttributedText {

	var attributedString: NSAttributedString { get }

	var linkAttributes: [NSAttributedString.Key: Any] { get }

	func process(url: URL)
}

public extension SoramitsuAttributedText {
	var linkAttributes: [NSAttributedString.Key: Any] { return [:] }
	func process(url: URL) {}
}

extension NSAttributedString: SoramitsuAttributedText {
	public var attributedString: NSAttributedString {
		return self
	}
}

extension Array: SoramitsuAttributedText where Element: SoramitsuAttributedText {
	public var attributedString: NSAttributedString {
		let result = NSMutableAttributedString()
		forEach { result.append($0.attributedString) }
		return result
	}

	public var linkAttributes: [NSAttributedString.Key: Any] {
		var result = [NSAttributedString.Key: Any]()
		forEach { result.merge($0.linkAttributes) { _, new in new } }
		return result
	}

	public func process(url: URL) {
		forEach { $0.process(url: url) }
	}
}
