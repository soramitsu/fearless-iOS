import Foundation

public final class KeychainManager {
    private static let queueLabel = "jp.co.soramitsu.fearless.secure-storage.concurrent"

    public static let shared = KeychainManager(qos: .default)

    public static func shared(with qos: DispatchQoS) -> KeychainManager {
        KeychainManager(qos: qos)
    }

    private let keystore: KeystoreProtocol
    private let queue: DispatchQueue

    public init(
        keystore: KeystoreProtocol = Keychain(),
        qos: DispatchQoS = .default
    ) {
        self.keystore = keystore
        queue = DispatchQueue(
            label: Self.queueLabel,
            qos: qos,
            attributes: .concurrent
        )
    }
}

extension KeychainManager: SecretStoreManagerProtocol {
    public func loadSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (SecretDataRepresentable?) -> Void
    ) {
        queue.async {
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
        queue.async(flags: .barrier) {
            guard let data = secret.asSecretData() else {
                completionQueue.async {
                    completionBlock(false)
                }
                return
            }

            let saved = (try? self.keystore.saveKey(data, with: identifier)) != nil
            completionQueue.async {
                completionBlock(saved)
            }
        }
    }

    public func removeSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        queue.async(flags: .barrier) {
            let removed = (try? self.keystore.deleteKeyIfExists(for: identifier)) != nil
            completionQueue.async {
                completionBlock(removed)
            }
        }
    }

    public func checkSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        queue.async {
            let exists = self.checkSecret(for: identifier)
            completionQueue.async {
                completionBlock(exists)
            }
        }
    }

    public func checkSecret(for identifier: String) -> Bool {
        (try? keystore.checkKey(for: identifier)) ?? false
    }
}
