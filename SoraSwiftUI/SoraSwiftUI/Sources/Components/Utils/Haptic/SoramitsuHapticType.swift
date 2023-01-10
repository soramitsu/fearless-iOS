public enum SoramitsuHapticType {
	case impact(SoramitsuHapticImpactType)
	case notification(SoramitsuHapticNotificationType)
}

public enum SoramitsuHapticImpactType {
	case heavy
	case light
	case medium
	case soft
}

public enum SoramitsuHapticNotificationType {
	case error
	case success
	case warning
}
