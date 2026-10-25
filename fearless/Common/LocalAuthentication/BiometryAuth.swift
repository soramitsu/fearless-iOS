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
    func cancelAuthentication()
    func authenticate(
        localizedReason: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    )
}

extension BiometryAuthProtocol {
    func cancelAuthentication() {}
}

class BiometryAuth: BiometryAuthProtocol {
    private let contextFactory: () -> LAContext
    private let contextLock = NSLock()
    private var activeContext: LAContext?
    private var activeAttempt: UUID?

    init(contextFactory: @escaping () -> LAContext = { LAContext() }) {
        self.contextFactory = contextFactory
    }

    deinit {
        activeContext?.invalidate()
    }

    var availableBiometryType: AvailableBiometryType {
        biometryType(for: contextFactory())
    }

    private func biometryType(for context: LAContext) -> AvailableBiometryType {
        let available = context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: nil)
        guard available else { return .none }

        if #available(iOS 11, *) {
            switch context.biometryType {
            case .touchID:
                return .touchId
            case .faceID:
                return .faceId
            case .opticID:
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
        let context = contextFactory()
        let attempt = UUID()
        contextLock.lock()
        let previousContext = activeContext
        activeContext = context
        activeAttempt = attempt
        contextLock.unlock()
        previousContext?.invalidate()

        let reply: (Bool) -> Void = { [weak self] result in
            completionQueue.async { [weak self] in
                guard let self else { return }
                self.contextLock.lock()
                guard self.activeAttempt == attempt else {
                    self.contextLock.unlock()
                    return
                }
                let completedContext = self.activeContext
                self.activeAttempt = nil
                self.activeContext = nil
                self.contextLock.unlock()
                completedContext?.invalidate()
                completionBlock(result)
            }
        }

        guard biometryType(for: context) != .none else {
            reply(false)
            return
        }
        context.evaluatePolicy(
            LAPolicy.deviceOwnerAuthenticationWithBiometrics,
            localizedReason: localizedReason
        ) { result, _ in reply(result) }
    }

    func cancelAuthentication() {
        contextLock.lock()
        let context = activeContext
        activeAttempt = nil
        activeContext = nil
        contextLock.unlock()
        context?.invalidate()
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

    var accessoryIconSettings: UIImage? {
        switch self {
        case .faceId:
            return R.image.pinFaceIdSettings()
        case .touchId:
            return R.image.pinFingerprintSettings()
        case .none:
            return nil
        }
    }
}
