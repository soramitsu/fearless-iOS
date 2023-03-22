import UIKit

public final class SoramitsuHaptic {

	public let type: SoramitsuHapticType

	private var generator: SoramitsuHapticable?

	public init(type: SoramitsuHapticType) {
		self.type = type
	}

	public static func tic(_ type: SoramitsuHapticType) {
		let haptic = SoramitsuHaptic(type: type)
		haptic.tic()
	}
}

extension SoramitsuHaptic: SoramitsuHapticable {

	public func prepare() {
		guard generator == nil else { return }
		switch type {
		case let .impact(impactType):
			generator = UIImpactFeedbackGenerator(style: impactType.style)
		case let .notification(notificationType):
			generator = GNotificationFeedbackGenerator(type: notificationType)
		}
		generator?.prepare()
	}

	public func prepare(if condition: Bool) {
		if condition {
			prepare()
		} else {
			generator = nil
		}
	}

	public func tic() {
		prepare()
		generator?.tic()
		generator = nil
	}
}

private extension SoramitsuHapticImpactType {

	var style: UIImpactFeedbackGenerator.FeedbackStyle {
		switch self {
		case .heavy: return .heavy
		case .light: return .light
		case .medium: return .medium
		case .soft:
			if #available(iOS 13.0, *) {
				return .soft
			} else {
				return .light
			}
		}
	}
}
