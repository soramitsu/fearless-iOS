import Foundation
import LocalAuthentication
import UIKit.UIImage

enum AvailableBiometryType {
    case none
    case touchId
    case faceId
}

protocol BiometryAuthProtocol {
    var availableBiometryType: AvailableBiometryType { get }
    func authenticate(
        localizedReason: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    )
}

class BiometryAuth: BiometryAuthProtocol {
    private lazy var context = LAContext()

    var availableBiometryType: AvailableBiometryType {
        let available = context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: nil)
        guard available else { return .none }

        if #available(iOS 11, *) {
            switch context.biometryType {
            case .touchID:
                return .touchId
            case .faceID:
                return .faceId
            case .none:
                return .none
            @unknown default:
                return .none
            }
        } else {
            return .touchId
        }
    }

    func authenticate(
        localizedReason: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        guard availableBiometryType != .none else {
            completionQueue.async {
                completionBlock(false)
            }
            return
        }

        context.evaluatePolicy(
            LAPolicy.deviceOwnerAuthenticationWithBiometrics,
            localizedReason: localizedReason
        ) { (result: Bool, _: Error?) -> Void in
            completionQueue.async {
                completionBlock(result)
            }
        }
    }
}

extension AvailableBiometryType {
    var accessoryIcon: UIImage? {
        switch self {
        case .faceId:
            return R.image.pinFaceId()
        case .touchId:
            return R.image.pinFingerprint()
        case .none:
            return nil
        }
    }
}
