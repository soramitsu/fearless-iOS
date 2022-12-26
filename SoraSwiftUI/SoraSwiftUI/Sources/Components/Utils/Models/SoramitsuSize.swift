import UIKit

public enum SoramitsuMeasurement {
	case constant(CGFloat)
	case flexible
}

public struct SoramitsuSize {

	public var width: SoramitsuMeasurement
	public var height: SoramitsuMeasurement
	public static var flexible: SoramitsuSize { return SoramitsuSize(width: .flexible, height: .flexible) }

	public init(width: SoramitsuMeasurement, height: SoramitsuMeasurement) {
		self.width = width
		self.height = height
	}
}

extension NSLayoutDimension {
	func constraint(equalTo measurement: SoramitsuMeasurement) -> NSLayoutConstraint? {
		switch measurement {
		case .flexible :return nil
		case .constant(let value):
			return constraint(equalToConstant: value)
		}
	}
}
