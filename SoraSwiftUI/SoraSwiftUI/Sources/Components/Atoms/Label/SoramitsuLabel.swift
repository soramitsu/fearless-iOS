import UIKit

public final class SoramitsuLabel: UILabel, Atom {
	public let sora: SoramitsuLabelConfiguration<SoramitsuLabel>

	public override var intrinsicContentSize: CGSize {
		let labelSize = super.intrinsicContentSize
		let width = sora.contentInsets.horizontal + labelSize.width
		let height = sora.contentInsets.vertical + labelSize.height
		return CGSize(width: width, height: height)
	}

	init(style: SoramitsuStyle) {
        sora = SoramitsuLabelConfiguration(style: style)
		super.init(frame: .zero)
        sora.owner = self
	}

	@available(*, unavailable)
	required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	@available(*, unavailable)
	public override init(frame: CGRect) { fatalError("init(coder:) has not been implemented") }

	override public func drawText(in rect: CGRect) {
		super.drawText(in: rect.inset(by: sora.contentInsets.uiEdgeInsets))
	}
}

public extension SoramitsuLabel {

	convenience init() {
		self.init(style: SoramitsuUI.shared.style)
	}

	convenience init(configurator: (SoramitsuLabelConfiguration<SoramitsuLabel>) -> Void) {
		self.init(style: SoramitsuUI.shared.style)
		configurator(sora)
	}
}
