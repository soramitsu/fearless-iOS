import UIKit

open class SoramitsuTextItem {

	public var text: String

	public var attributes: SoramitsuTextAttributes

	private let style: SoramitsuStyle
	private let fakeURL = URL(fileURLWithPath: UUID().uuidString)

	private var stringAttributes: [NSAttributedString.Key: Any] {
		var stringAttributes = attributes.fontData.attributes
        let paragraph = attributes.fontData.paragraph

		if let alignment = attributes.alignment {
			paragraph.alignment = alignment
		}
		if let underlineStyle = attributes.underline {
			stringAttributes[.underlineStyle] = underlineStyle.rawValue
		}

		stringAttributes[.paragraphStyle] = paragraph
		stringAttributes[.foregroundColor] = style.palette.color(attributes.textColor)

		return stringAttributes
	}

	init(style: SoramitsuStyle, text: String, attributes: SoramitsuTextAttributes) {
		self.style = style
		self.text = text
		self.attributes = attributes
	}
}

public extension SoramitsuTextItem {

	convenience init(text: String, attributes: SoramitsuTextAttributes) {
		self.init(style: SoramitsuUI.shared.style,
				  text: text,
				  attributes: attributes)
	}

	convenience init(text: String,
					 fontData: FontData,
                     textColor: SoramitsuColor = .accentPrimary,
					 alignment: NSTextAlignment = .left,
					 underline: NSUnderlineStyle? = nil) {
        let attributes = SoramitsuTextAttributes(fontData: fontData,
										 textColor: textColor,
										 alignment: alignment,
										 underline: underline)
		self.init(style: SoramitsuUI.shared.style,
				  text: text,
				  attributes: attributes)
	}
}

extension SoramitsuTextItem: SoramitsuAttributedText {
	public var attributedString: NSAttributedString {
		var stringAttributes = self.stringAttributes
		if attributes.linkTapHandler != nil {
			stringAttributes[.link] = fakeURL
		}
		return NSAttributedString(string: text, attributes: stringAttributes)
	}

	public var linkAttributes: [NSAttributedString.Key: Any] {
		attributes.linkTapHandler == nil ? [:] : stringAttributes
	}

	public func process(url: URL) {
		if url.absoluteString == fakeURL.absoluteString {
			attributes.linkTapHandler?()
		}
	}
}
