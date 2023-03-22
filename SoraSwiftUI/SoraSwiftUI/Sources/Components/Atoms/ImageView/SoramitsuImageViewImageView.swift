import UIKit

public final class SoramitsuImageView: UIImageView, Atom {

	public let sora: SoramitsuImageViewConfiguration<SoramitsuImageView>

	init(style: SoramitsuStyle) {
		sora = SoramitsuImageViewConfiguration(style: style)
		super.init(frame: .zero)
		sora.owner = self
	}

	@available(*, unavailable)
	required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	@available(*, unavailable)
	public override init(frame: CGRect) { fatalError("init(coder:) has not been implemented") }
}

public extension SoramitsuImageView {
	convenience init() {
		self.init(style: SoramitsuUI.shared.style)
	}

	convenience init(configurator: (SoramitsuImageViewConfiguration<SoramitsuImageView>) -> Void) {
		self.init(style: SoramitsuUI.shared.style)
		configurator(sora)
	}
}
