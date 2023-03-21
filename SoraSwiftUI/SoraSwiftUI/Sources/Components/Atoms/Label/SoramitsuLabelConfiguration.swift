import UIKit

public class SoramitsuLabelConfiguration<Type: UILabel & Atom>: SoramitsuViewConfiguration<Type> {

	// MARK: Text

	public var text: String? {
		didSet {
			updateAttributedText()
		}
	}

	public var attributedText: SoramitsuAttributedText? {
		didSet {
			updateAttributedText()
		}
	}

	// MARK: Attributes

    public var textColor: SoramitsuColor = .accentPrimary {
		didSet {
			updateAttributedText()
		}
	}

    public var font: FontData = FontType.buttonM {
		didSet {
			updateAttributedText()
		}
	}

	public var alignment: NSTextAlignment = .left {
		didSet {
			updateAttributedText()
		}
	}

	public var lineBreakMode: NSLineBreakMode = .byTruncatingTail {
		didSet {
			updateAttributedText()
		}
	}

	// MARK: Other

    public var contentInsets: SoramitsuInsets = .zero {
        didSet {
            owner?.rebuildLayout()
        }
    }

	public var numberOfLines: Int = 1 {
		didSet {
			owner?.numberOfLines = numberOfLines
		}
	}

	public var underlineStyle: NSUnderlineStyle? {
		didSet {
			updateAttributedText()
		}
	}

	public override func styleDidChange(options: UpdateOptions) {
		super.styleDidChange(options: options)

		if options.contains(.palette) {
			updateAttributedText()
		}
	}

	func updateAttributedText() {
		guard attributedText == nil else {
			owner?.attributedText = attributedText?.attributedString
			return
		}
		guard let text = text else {
			owner?.attributedText = nil
			return
		}

		var attributes = font.attributes

		let paragraph = font.paragraph
		paragraph.alignment = alignment
		paragraph.lineBreakMode = lineBreakMode

		attributes[.paragraphStyle] = paragraph
		attributes[.foregroundColor] = style.palette.color(textColor)
		if let underlineStyle = underlineStyle {
			attributes[.underlineStyle] = underlineStyle.rawValue
		}

		owner?.attributedText = NSAttributedString(string: text, attributes: attributes)
	}
}
