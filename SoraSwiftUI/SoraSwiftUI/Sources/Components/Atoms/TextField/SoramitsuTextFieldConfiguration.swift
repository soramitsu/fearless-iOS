import UIKit

public class SoramitsuTextFieldConfiguration<Type: SoramitsuTextField>: SoramitsuControlConfiguration<Type> {

	public var text: String? {
		didSet(oldText) {
			guard text != oldText else { return }
			updateTextAttributes()
		}
	}
    
    public var attributedText: SoramitsuTextItem? {
        didSet {
            owner?.attributedText = attributedText?.attributedString
        }
    }

    public var textColor: SoramitsuColor = .fgPrimary {
		didSet {
			updateTextAttributes()
		}
	}

    public var font: FontData = FontType.textM {
		didSet {
			updateTextAttributes()
		}
	}

	public var placeholder: String? {
		didSet {
			updatePlaceholderAttributes()
		}
	}

    public var placeholderColor: SoramitsuColor = .fgSecondary {
		didSet {
			updatePlaceholderAttributes()
		}
	}

    public var placeholderFont: FontData = FontType.textM {
		didSet {
			updatePlaceholderAttributes()
		}
	}
    
	private var textObservation: NSKeyValueObservation?

	override init(style: SoramitsuStyle) {
		super.init(style: style)
        tintColor = .fgPrimary
	}

	public override func styleDidChange(options: UpdateOptions) {
		super.styleDidChange(options: options)

		if options.contains(.palette) {
			retrigger(self, \.textColor)
			retrigger(self, \.placeholderColor)
			updateKeyboardAppearence()
		}
	}

	override func configureOwner() {
		super.configureOwner()

		retrigger(self, \.textColor)
		retrigger(self, \.tintColor)
		retrigger(self, \.font)
		retrigger(self, \.placeholderColor)
		retrigger(self, \.placeholderFont)

		updateKeyboardAppearence()

		addHandler(for: .editingChanged) { [weak self] in
			self?.text = self?.owner?.text
		}

		textObservation = owner?.observe(\.text, options: .new) { [weak self] _, _ in
			self?.text = self?.owner?.text
		}
	}

    private func updateTextAttributes() {
		guard let owner = owner, let text = text else { return }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = owner.textAlignment
        
		var attributes = font.attributes
		attributes[.foregroundColor] = style.palette.color(textColor)
        attributes[.paragraphStyle] = paragraphStyle
		let selectedRange = owner.selectedTextRange
		owner.attributedText = NSAttributedString(string: text, attributes: attributes)
		owner.selectedTextRange = selectedRange
		owner.defaultTextAttributes = attributes
	}

    private func updatePlaceholderAttributes() {
		guard let placeholder = placeholder else { return }
		var attributes = placeholderFont.attributes
		attributes[.foregroundColor] = style.palette.color(placeholderColor)
		owner?.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: attributes)
	}

    private func updateKeyboardAppearence() {
		switch SoramitsuUI.shared.theme {
		case .light: owner?.keyboardAppearance = .light
		case .dark: owner?.keyboardAppearance = .dark
		}
	}
}

