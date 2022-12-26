import CoreGraphics

public enum Radius {
	case zero
    /// 12
	case small
    /// 16
	case medium
    /// 20
	case large
    /// 24
	case extraLarge
    /// 32
    case max
	case circle
    case custom(CGFloat)
}

protocol Radii {
	var small: CGFloat { get }
	var medium: CGFloat { get }
	var large: CGFloat { get }
	var extraLarge: CGFloat { get }
    var max: CGFloat { get }
}

extension Radii {
	func radius(_ gRadius: Radius, size: CGSize) -> CGFloat {
		switch gRadius {
		case .zero: return 0
		case .small: return small
		case .medium: return medium
		case .large: return large
		case .extraLarge: return extraLarge
        case .max: return max
		case .circle: return min(size.width, size.height) / 2.0
        case .custom(let radius): return radius
		}
	}
}
