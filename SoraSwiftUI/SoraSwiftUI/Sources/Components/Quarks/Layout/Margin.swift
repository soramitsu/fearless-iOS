import CoreGraphics

@objc public enum Margin: Int, CaseIterable {

	case zero

	case atom

	case molecule

	case organism

	public var value: CGFloat {
		return SoramitsuUI.shared.style.layout.value(margin: self)
	}
}
