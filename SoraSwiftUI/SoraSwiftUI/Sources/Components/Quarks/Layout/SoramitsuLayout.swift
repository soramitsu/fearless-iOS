import CoreGraphics

protocol SoramitsuLayout {
	func value(gap: Gap) -> CGFloat
	func value(horizontalPadding: Padding.Horizontal) -> CGFloat
	func value(verticalPadding: Padding.Vertical) -> CGFloat
	func value(margin: Margin) -> CGFloat
}
