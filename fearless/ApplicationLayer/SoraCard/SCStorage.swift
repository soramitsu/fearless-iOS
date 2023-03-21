import Foundation
import SoraKeystore

final class SCStorage {
    static let shared = SCStorage(secretManager: KeychainManager.shared)

    init(secretManager: SecretStoreManagerProtocol) {
        self.secretManager = secretManager

        Task {
            if isFirstLaunch() {
                await removeToken()
                setAppLaunched()
            }
        }
    }

    private let secretManager: SecretStoreManagerProtocol

    private enum Key: String {
        case kycId = "SCKycId"
        case accessToken = "SCAccessToken"
        case isHidden = "SCIsHidden"
        case isRetry = "SCIsRetry"
        case isAppStarted = "SCIsAppStarted"
    }

    func kycId() -> String? {
        UserDefaults.standard.string(forKey: Key.kycId.rawValue)
    }

    func add(kycId: String?) {
        UserDefaults.standard.set(kycId, forKey: Key.kycId.rawValue)
    }

    func isSCBannerHidden() -> Bool {
        UserDefaults.standard.bool(forKey: Key.isHidden.rawValue)
    }

    func set(isHidden: Bool) {
        UserDefaults.standard.set(isHidden, forKey: Key.isHidden.rawValue)
    }

    func isKYCRetry() -> Bool {
        UserDefaults.standard.bool(forKey: Key.isRetry.rawValue)
    }

    func set(isRetry: Bool) {
        UserDefaults.standard.set(isRetry, forKey: Key.isRetry.rawValue)
    }

    private func isFirstLaunch() -> Bool {
        !UserDefaults.standard.bool(forKey: Key.isAppStarted.rawValue)
    }

    private func setAppLaunched() {
        UserDefaults.standard.set(true, forKey: Key.isAppStarted.rawValue)
    }

    func token() async -> SCToken? {
        await withCheckedContinuation { continuation in
            secretManager.loadSecret(for: Key.accessToken.rawValue, completionQueue: DispatchQueue.main) { secretDataRepresentable in
                continuation.resume(returning: SCToken(secretData: secretDataRepresentable))
            }
        }
    }

    func hasToken() -> Bool {
        secretManager.checkSecret(for: Key.accessToken.rawValue)
    }

    func add(token: SCToken) async {
        await withCheckedContinuation { continuation in
            guard let data = token.asSecretData() else { return }
            secretManager.saveSecret(
                data,
                for: Key.accessToken.rawValue,
                completionQueue: DispatchQueue.main
            ) { _ in
                continuation.resume()
            }
        }
    }

    func removeToken() async {
        await withCheckedContinuation { continuation in
            secretManager.removeSecret(for: Key.accessToken.rawValue, completionQueue: DispatchQueue.main) { _ in
                continuation.resume()
            }
        }
    }
}
