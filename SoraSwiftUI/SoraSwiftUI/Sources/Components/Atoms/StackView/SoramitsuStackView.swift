import UIKit

open class SoramitsuStackView: UIStackView, Atom {

	public let sora: SoramitsuStackViewConfiguration<SoramitsuStackView>

	public override init(frame: CGRect) {
		sora = SoramitsuStackViewConfiguration(style: SoramitsuUI.shared.style)
		super.init(frame: .zero)
        sora.owner = self
	}

	init(style: SoramitsuStyle) {
		sora = SoramitsuStackViewConfiguration(style: style)
		super.init(frame: .zero)
		sora.owner = self
	}

	@available(*, unavailable)
    required public init(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

public extension SoramitsuStackView {

	convenience init() {
		self.init(style: SoramitsuUI.shared.style)
	}

	convenience init(arrangedSubviews: UIView...) {
		self.init(style: SoramitsuUI.shared.style)
		addArrangedSubviews(arrangedSubviews)
	}

	convenience init(configurator: (SoramitsuStackViewConfiguration<SoramitsuStackView>) -> Void) {
		self.init(style: SoramitsuUI.shared.style)
		configurator(sora)
	}
}
