import Foundation
import Security
import SoraKeystore

/// The shipped Keychain implementation stores wallet material as kSecClassKey
/// with a UTF8 application tag. Enumerate tags rather than decoded wallet rows:
/// damaged or unsupported rows must not strand their still-readable keys.
final class EmergencyWalletMaterialReader: EmergencyWalletMaterialReading {
    static let walletSuffixes = [
        "-secretKey", "-entropy", "-deriv", "-seed",
        "-substrateSecretKey", "-ethereumSecretKey", "-tonSecretKey",
        "-substrateDeriv", "-ethereumDeriv", "-substrateSeed", "-ethereumSeed",
        "-universalWalletSecretSource"
    ]

    private let tags: () throws -> [String]
    private let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol = Keychain(), tags: @escaping () throws -> [String] = walletTags) {
        self.keystore = keystore
        self.tags = tags
    }

    static func isWalletTag(_ tag: String) -> Bool {
        walletSuffixes.contains { tag.hasSuffix($0) && tag.count > $0.count }
    }

    static func walletTags() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            throw KeystoreError.unexpectedFail
        }
        return items.compactMap { item in
            guard let bytes = item[kSecAttrApplicationTag as String] as? Data,
                  let tag = String(data: bytes, encoding: .utf8), isWalletTag(tag) else { return nil }
            return tag
        }
    }

    func read() throws -> EmergencyWalletMaterial {
        var records: [EmergencyWalletMaterial.Record] = []
        var unreadable: [String] = []
        for tag in try Set(tags()).filter(Self.isWalletTag).sorted() {
            do {
                let bytes = try keystore.fetchKey(for: tag)
                records.append(.init(tag: tag, bytesBase64: bytes.base64EncodedString()))
            } catch {
                unreadable.append(tag)
            }
        }
        return EmergencyWalletMaterial(records: records, unreadableTags: unreadable)
    }
}

/// Authentication is deliberately upstream of enumeration and reading. Callers
/// cannot accidentally perform an export while waiting for the PIN screen.
final class EmergencyWalletMaterialAccess {
    private let reader: EmergencyWalletMaterialReading

    init(reader: EmergencyWalletMaterialReading) {
        self.reader = reader
    }

    func read(
        authorize: (@escaping (Bool) -> Void) -> Void,
        completion: @escaping (Result<EmergencyWalletMaterial, Error>?) -> Void
    ) {
        let lock = NSLock()
        var resolved = false
        authorize { [reader] granted in
            lock.lock()
            guard !resolved else { lock.unlock(); return }
            resolved = true
            lock.unlock()
            guard granted else {
                completion(nil)
                return
            }
            completion(Result { try reader.read() })
        }
    }
}
