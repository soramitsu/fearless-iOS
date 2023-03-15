import CoreGraphics

public enum SoramitsuPosition {
	case leftTop
	case rightTop
	case rightBottom
	case leftBottom
	case leftCenter
	case rightCenter
	case topCenter
	case bottomCenter
	case center
	case custom(x: CGFloat, y: CGFloat)

	/// Нормальзованная точка
	public var normalizedPoint: CGPoint {
		switch self {
		case .leftTop: return .zero
		case .rightTop: return CGPoint(x: 1, y: 0)
		case .rightBottom: return CGPoint(x: 1, y: 1)
		case .leftBottom: return CGPoint(x: 0, y: 1)
		case .leftCenter: return CGPoint(x: 0, y: 0.5)
		case .rightCenter: return CGPoint(x: 1, y: 0.5)
		case .topCenter: return CGPoint(x: 0.5, y: 0)
		case .bottomCenter: return CGPoint(x: 0.5, y: 1)
		case .center: return CGPoint(x: 0.5, y: 0.5)
		case let .custom(x, y): return CGPoint(x: x, y: y)
		}
	}
}
