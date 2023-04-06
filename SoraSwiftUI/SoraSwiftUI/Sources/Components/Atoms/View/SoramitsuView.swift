import UIKit

open class SoramitsuView: UIView, Atom {

	public let sora: SoramitsuViewConfiguration<SoramitsuView>

	public override init(frame: CGRect = .zero) {
        sora = SoramitsuViewConfiguration(style: SoramitsuUI.shared.style)
		super.init(frame: frame)
        sora.owner = self
	}

	public convenience init(configurator: (SoramitsuViewConfiguration<SoramitsuView>) -> Void) {
		self.init(frame: .zero)
		configurator(sora)
	}

	init(style: SoramitsuStyle, frame: CGRect = .zero) {
        sora = SoramitsuViewConfiguration(style: style)
		super.init(frame: frame)
        sora.owner = self
	}

	@available(*, unavailable)
	required public init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
