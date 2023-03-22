import CoreGraphics

@objc public enum Gap: Int, CaseIterable {

	case zero

	case text

	case atom

	case molecule

	public var value: CGFloat {
		return SoramitsuUI.shared.style.layout.value(gap: self)
	}
}
