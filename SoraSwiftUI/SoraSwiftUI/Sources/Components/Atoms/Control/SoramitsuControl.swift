import UIKit

open class SoramitsuControl: UIControl, Atom {
	public let sora: SoramitsuControlConfiguration<SoramitsuControl>

	public override init(frame: CGRect) {
        sora = SoramitsuControlConfiguration(style: SoramitsuUI.shared.style)
		super.init(frame: frame)
        sora.owner = self
	}

	init(style: SoramitsuStyle) {
        sora = SoramitsuControlConfiguration(style: style)
		super.init(frame: .zero)
        sora.owner = self
	}

	@available(*, unavailable)
	required public init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

public extension SoramitsuControl {
	convenience init() {
		self.init(style: SoramitsuUI.shared.style)
	}
}
