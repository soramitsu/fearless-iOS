import CoreGraphics
import UIKit

public enum SoramitsuInsetEdge {
	case top
	case left
	case bottom
	case right
}

public struct SoramitsuInsets {
	public let top: CGFloat
	public let left: CGFloat
	public let bottom: CGFloat
	public let right: CGFloat

	public var horizontal: CGFloat {
		return left + right
	}

	public var vertical: CGFloat {
		return top + bottom
	}

	public var uiEdgeInsets: UIEdgeInsets {
		return UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
	}

	public init(top: CGFloat = 0.0, left: CGFloat = 0.0, bottom: CGFloat = 0.0, right: CGFloat = 0.0) {
		self.top = top
		self.left = left
		self.bottom = bottom
		self.right = right
	}

	public init(all: CGFloat) {
		self.top = all
		self.left = all
		self.bottom = all
		self.right = all
	}

	public init(top: Padding.Vertical = .zero,
				left: Padding.Horizontal = .zero,
				bottom: Padding.Vertical = .zero,
				right: Padding.Horizontal = .zero) {
		self.top = top.value
		self.left = left.value
		self.bottom = bottom.value
		self.right = right.value
	}

	public init(horizontal: CGFloat = 0, vertical: CGFloat = 0) {
		self.top = vertical
		self.left = horizontal
		self.bottom = vertical
		self.right = horizontal
	}

	public init(horizontal: Padding.Horizontal = .zero, vertical: Padding.Vertical = .zero) {
		self.top = vertical.value
		self.left = horizontal.value
		self.bottom = vertical.value
		self.right = horizontal.value
	}

	public static var zero: SoramitsuInsets {
		return SoramitsuInsets(all: 0)
	}

	public static func + (first: SoramitsuInsets, second: SoramitsuInsets) -> SoramitsuInsets {
		return SoramitsuInsets(top: first.top + second.top,
					   left: first.left + second.left,
					   bottom: first.bottom + second.bottom,
					   right: first.right + second.right)
	}

	public var size: CGSize {
		return CGSize(width: horizontal, height: vertical)
	}

	public var point: CGPoint {
		return CGPoint(x: left, y: top)
	}

	public func insetsByRemoving(_ edge: SoramitsuInsetEdge) -> SoramitsuInsets {
		return replace(edge, to: 0)
	}

	public func replace(_ edge: SoramitsuInsetEdge, to value: CGFloat) -> SoramitsuInsets {
		switch edge {
		case .top:
			return SoramitsuInsets(top: value, left: left, bottom: bottom, right: right)
		case .left:
			return SoramitsuInsets(top: top, left: value, bottom: bottom, right: right)
		case .bottom:
			return SoramitsuInsets(top: top, left: left, bottom: value, right: right)
		case .right:
			return SoramitsuInsets(top: top, left: left, bottom: bottom, right: value)
		}
	}
}
