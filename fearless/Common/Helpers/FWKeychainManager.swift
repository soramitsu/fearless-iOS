import Foundation
import SoraKeystore

final class FWKeychainManager {
    static let shared = FWKeychainManager()
    fileprivate static let queueLabel = "jp.co.soramitsu.fearless.keychain.concurrent"

    private lazy var concurentQueue = DispatchQueue(
        label: FWKeychainManager.queueLabel,
        qos: .userInteractive,
        attributes: .concurrent
    )
    private lazy var keystore = Keychain()

    private init() {}
}

extension FWKeychainManager: SecretStoreManagerProtocol {
    public func loadSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (SecretDataRepresentable?) -> Void
    ) {
        concurentQueue.async {
            let data = try? self.keystore.fetchKey(for: identifier)

            completionQueue.async {
                completionBlock(data)
            }
        }
    }

    public func saveSecret(
        _ secret: SecretDataRepresentable,
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        concurentQueue.async {
            guard let secretExists = try? self.keystore.checkKey(for: identifier) else {
                completionQueue.async {
                    completionBlock(false)
                }
                return
            }

            guard let secretData = secret.asSecretData() else {
                completionQueue.async {
                    completionBlock(false)
                }
                return
            }

            do {
                if !secretExists {
                    try self.keystore.addKey(secretData, with: identifier)
                } else {
                    try self.keystore.updateKey(secretData, with: identifier)
                }

                completionQueue.async {
                    completionBlock(true)
                }

            } catch {
                completionQueue.async {
                    completionBlock(false)
                }
            }
        }
    }

    public func removeSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        concurentQueue.async {
            guard let secretExists = try? self.keystore.checkKey(for: identifier), secretExists else {
                completionQueue.async {
                    completionBlock(false)
                }
                return
            }

            do {
                try self.keystore.deleteKey(for: identifier)

                completionQueue.async {
                    completionBlock(true)
                }

            } catch {
                completionQueue.async {
                    completionBlock(false)
                }
            }
        }
    }

    public func checkSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        concurentQueue.async {
            let result = self.checkSecret(for: identifier)

            completionQueue.async {
                completionBlock(result)
            }
        }
    }

    public func checkSecret(for identifier: String) -> Bool {
        (try? keystore.checkKey(for: identifier)) ?? false
    }
}
