import UIKit

/// Поле ввода
public final class SoramitsuTextField: UITextField, Atom {

	public let sora: SoramitsuTextFieldConfiguration<SoramitsuTextField>

	/// Конструктор
	///
	/// - Parameter style: стиль
	init(style: SoramitsuStyle) {
		sora = SoramitsuTextFieldConfiguration(style: style)
		super.init(frame: .zero)
        sora.owner = self
	}

	@available(*, unavailable)
	required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	@available(*, unavailable)
	public override init(frame: CGRect) { fatalError("init(coder:) has not been implemented") }
}

extension SoramitsuTextField: UITextFieldDelegate {
    override public func caretRect(for position: UITextPosition) -> CGRect {
        var rect = super.caretRect(for: position)
        rect.size.height = 20
        return rect
    }
}

public extension SoramitsuTextField {

	convenience init() {
		self.init(style: SoramitsuUI.shared.style)
	}

	convenience init(configurator: (SoramitsuTextFieldConfiguration<SoramitsuTextField>) -> Void) {
		self.init(style: SoramitsuUI.shared.style)
		configurator(sora)
	}
}
