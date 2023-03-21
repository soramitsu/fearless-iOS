import CoreGraphics

struct DefaultLayout: SoramitsuLayout {
	func value(gap: Gap) -> CGFloat {
		switch gap {
		case .zero:
			return 0
		case .text:
			return 4
		case .atom:
			return 12
		case .molecule:
			return 16
		}
	}

	func value(horizontalPadding: Padding.Horizontal) -> CGFloat {
		switch horizontalPadding {
		case .zero:
			return 0
		case .smallest:
			return 8
		case .molecule:
			return 16
		case .edge:
			return ScreenSizeMapper.value(small: 12, other: 24)
		}
	}

	func value(verticalPadding: Padding.Vertical) -> CGFloat {
		switch verticalPadding {
		case .zero:
			return 0
		case .smallest:
			return 8
		case .atom:
			return 12
		case .molecule:
			return 16
		case .organism:
			return 16
		}
	}

	func value(margin: Margin) -> CGFloat {
		switch margin {
		case .zero:
			return 0
		case .atom:
			return 12
		case .molecule:
			return 12
		case .organism:
			return 8
		}
	}
}
