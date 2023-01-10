import UIKit

public enum Picture {

	case logo(image: UIImage)

	case icon(image: UIImage, color: SoramitsuColor)

	public var image: UIImage {
		switch self {
		case .logo(let image): return image
		case .icon(let image, _): return image
		}
	}

	public mutating func repaint(to color: SoramitsuColor) {
		switch self {
		case let .icon(image, _):
			self = .icon(image: image, color: color)
		default: break
		}
	}
}
