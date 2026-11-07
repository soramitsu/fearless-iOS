import Foundation
import LocalAuthentication
import SoraKeystore
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

    /// The device's biometric enrollment fingerprint. It changes when a face or finger is added or removed, and nil
    /// means biometrics cannot be evaluated now (none enrolled, or locked by the system).
    static func currentEnrollmentState(context: LAContext = LAContext()) -> Data? {
        currentEnrollment(context: context)?.state
    }

    /// The fingerprint together with the API that produced it: iOS 18 replaced `evaluatedPolicyDomainState` with
    /// `domainState.biometry.stateHash`, and the two describe the same enrollment with different bytes.
    static func currentEnrollment(context: LAContext = LAContext()) -> BiometryEnrollment? {
        defer { context.invalidate() }
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return nil
        }
        #if compiler(>=6.0)
            if #available(iOS 18.0, *) {
                return context.domainState.biometry.stateHash.map {
                    BiometryEnrollment(source: BiometryEnrollment.stateHashSource, state: $0)
                }
            }
        #endif
        return context.evaluatedPolicyDomainState.map {
            BiometryEnrollment(source: BiometryEnrollment.domainStateSource, state: $0)
        }
    }
}

struct BiometryEnrollment: Codable, Equatable {
    static let domainStateSource = "evaluatedPolicyDomainState"
    static let stateHashSource = "domainState.biometry.stateHash"

    let source: String
    let state: Data
}

/// A biometric success counts only while the device's enrollment equals the one recorded for this wallet, so a face
/// or finger added later cannot unlock the wallet or approve a transfer. The record lives in the Keychain.
protocol BiometryEnrollmentGuarding: AnyObject {
    /// True when the current enrollment equals the recorded one. An unreadable state is not trusted.
    func isCurrentEnrollmentTrusted() -> Bool
    /// Records the current enrollment. Call only right after the PIN was entered correctly or created.
    func trustCurrentEnrollment()
}

final class BiometryEnrollmentGuard: BiometryEnrollmentGuarding {
    static let shared = BiometryEnrollmentGuard()

    private let keystore: KeystoreProtocol
    private let currentState: () -> BiometryEnrollment?
    private let tag = KeystoreTag.biometryEnrollment.rawValue

    init(
        keystore: KeystoreProtocol = Keychain(),
        currentState: @escaping () -> BiometryEnrollment? = { BiometryAuth.currentEnrollment() }
    ) {
        self.keystore = keystore
        self.currentState = currentState
    }

    func isCurrentEnrollmentTrusted() -> Bool {
        guard let current = currentState(), !current.state.isEmpty else {
            return false
        }

        guard let recorded = recordedEnrollment(), recorded.source == current.source else {
            // No record: the install predates this check, and its user may rely on Face ID or Touch ID because the
            // PIN is forgotten. Demanding the PIN now would lock them out of their keys, so the enrollment present
            // at this first check is trusted, as every earlier version did, and the wallet is held to it from now on.
            // A changed source is the same enrollment read through the newer iOS API; it is re-recorded the same way.
            save(current)
            return true
        }

        return recorded.state == current.state
    }

    func trustCurrentEnrollment() {
        // Without a readable state the earlier record stays: it still names the enrollment the user vouched for.
        guard let current = currentState(), !current.state.isEmpty, recordedEnrollment() != current else {
            return
        }
        save(current)
    }

    private func recordedEnrollment() -> BiometryEnrollment? {
        guard let data = try? keystore.fetchKey(for: tag) else {
            return nil
        }
        return try? JSONDecoder().decode(BiometryEnrollment.self, from: data)
    }

    private func save(_ enrollment: BiometryEnrollment) {
        guard let data = try? JSONEncoder().encode(enrollment) else {
            return
        }
        try? keystore.saveKey(data, with: tag)
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
