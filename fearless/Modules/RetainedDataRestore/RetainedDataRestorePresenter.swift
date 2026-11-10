import Foundation
import IrohaCrypto
import Security
import SoraKeystore
import SSFUtils
import TweetNacl

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

// MARK: - Encrypted export

/// The emergency export never leaves the app in plain text. It is the
/// `fearless-emergency-material-v1` JSON sealed with the same construction as a
/// Polkadot JSON keystore and the Google Drive backup:
/// `encoded = salt(32) | N | p | r (u32 LE) | nonce(24) | XSalsa20-Poly1305(JSON)`,
/// keyed by scrypt(password UTF-8, salt, N=32768, r=8, p=1). The open-source script
/// `scripts/recovery/decrypt-emergency-material.py` (Python standard library only)
/// and polkadot.js `jsonDecryptData` both open it.
struct EncryptedEmergencyWalletMaterial: Codable, Equatable {
    static let formatIdentifier = "fearless-emergency-material-encrypted-v1"
    static let encodingIdentifiers = ["scrypt", "xsalsa20-poly1305"]

    let format: String
    let encoding: [String]
    let encoded: String
    let records: Int
    let unreadable: Int
}

enum EmergencyWalletMaterialEncryptionError: Error, Equatable {
    case weakPassword
    case invalidFile
    case wrongPasswordOrDamagedFile
    case verificationFailed
}

protocol EmergencyWalletMaterialEncrypting {
    func encrypt(_ material: EmergencyWalletMaterial, password: String) throws -> Data
}

final class EmergencyWalletMaterialEncryptor: EmergencyWalletMaterialEncrypting {
    private let makeScryptParameters: () throws -> ScryptParameters
    private let makeNonce: () throws -> Data

    init(
        makeScryptParameters: @escaping () throws -> ScryptParameters = { try ScryptParameters() },
        makeNonce: @escaping () throws -> Data = EmergencyWalletMaterialEncryptor.randomNonce
    ) {
        self.makeScryptParameters = makeScryptParameters
        self.makeNonce = makeNonce
    }

    static func isAcceptablePassword(_ password: String) -> Bool {
        NSPredicate.backupPassword.evaluate(with: password)
    }

    func encrypt(_ material: EmergencyWalletMaterial, password: String) throws -> Data {
        guard Self.isAcceptablePassword(password) else {
            throw EmergencyWalletMaterialEncryptionError.weakPassword
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let plaintext = try encoder.encode(material)

        let parameters = try makeScryptParameters()
        let nonce = try makeNonce()
        let key = try Self.deriveKey(password: password, parameters: parameters)
        let box = try NaclSecretBox.secretBox(message: plaintext, nonce: nonce, key: key)
        let envelope = EncryptedEmergencyWalletMaterial(
            format: EncryptedEmergencyWalletMaterial.formatIdentifier,
            encoding: EncryptedEmergencyWalletMaterial.encodingIdentifiers,
            encoded: (parameters.encode() + nonce + box).base64EncodedString(),
            records: material.records.count,
            unreadable: material.unreadableTags.count
        )

        let fileEncoder = JSONEncoder()
        fileEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let file = try fileEncoder.encode(envelope)

        // A recovery file that cannot be opened again is worse than none: prove it
        // round-trips before anyone relies on it.
        guard try Self.decrypt(file, password: password) == material else {
            throw EmergencyWalletMaterialEncryptionError.verificationFailed
        }

        return file
    }

    static func decrypt(_ file: Data, password: String) throws -> EmergencyWalletMaterial {
        guard
            let envelope = try? JSONDecoder().decode(EncryptedEmergencyWalletMaterial.self, from: file),
            envelope.format == EncryptedEmergencyWalletMaterial.formatIdentifier,
            envelope.encoding == EncryptedEmergencyWalletMaterial.encodingIdentifiers,
            let encoded = Data(base64Encoded: envelope.encoded),
            encoded.count > ScryptParameters.encodedLength + KeystoreConstants.nonceLength
            + KeystoreConstants.authenticationTagLength
        else {
            throw EmergencyWalletMaterialEncryptionError.invalidFile
        }

        let parameters = try ScryptParameters(data: encoded)
        let nonceStart = ScryptParameters.encodedLength
        let nonceEnd = nonceStart + KeystoreConstants.nonceLength
        let nonce = Data(encoded[nonceStart ..< nonceEnd])
        let box = Data(encoded[nonceEnd...])
        let key = try deriveKey(password: password, parameters: parameters)

        let plaintext: Data
        do {
            plaintext = try NaclSecretBox.open(box: box, nonce: nonce, key: key)
        } catch {
            throw EmergencyWalletMaterialEncryptionError.wrongPasswordOrDamagedFile
        }

        return try JSONDecoder().decode(EmergencyWalletMaterial.self, from: plaintext)
    }

    static func randomNonce() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: KeystoreConstants.nonceLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw KeystoreError.unexpectedFail
        }
        return Data(bytes)
    }

    private static func deriveKey(password: String, parameters: ScryptParameters) throws -> Data {
        try IRScryptKeyDeriviation().deriveKey(
            from: Data(password.utf8),
            salt: parameters.salt,
            scryptN: UInt(parameters.scryptN),
            scryptP: UInt(parameters.scryptP),
            scryptR: UInt(parameters.scryptR),
            length: UInt(KeystoreConstants.encryptionKeyLength)
        )
    }
}

// MARK: - Sensitive temporary files

/// Files that hold wallet secrets (encrypted JSON keystores, the encrypted emergency
/// export) live in their own temporary directory with complete data protection and
/// are removed as soon as the share sheet finishes, when the screen locks, and at the
/// next launch if the app stopped before that.
enum SensitiveExportFiles {
    static let directoryPrefix = "fearless-sensitive-export-"
    /// Directory prefix used by JSON exports before 4.2.1; still cleaned at launch.
    static let legacyJsonDirectoryPrefix = "fearless-json-"

    static func write(
        _ data: Data,
        fileName: String,
        fileManager: FileManager = .default,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let directory = temporaryDirectory.appendingPathComponent(
            directoryPrefix + UUID().uuidString,
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )

        do {
            let file = directory.appendingPathComponent(fileName, isDirectory: false)
            try data.write(to: file, options: [.withoutOverwriting, .completeFileProtection])
            return file
        } catch {
            try? fileManager.removeItem(at: directory)
            throw error
        }
    }

    /// Removes the per-export directory that holds `file`, and nothing else.
    static func remove(_ file: URL, fileManager: FileManager = .default) {
        let directory = file.deletingLastPathComponent()
        guard directory.lastPathComponent.hasPrefix(directoryPrefix) else {
            return
        }
        try? fileManager.removeItem(at: directory)
    }

    /// Inbox files younger than this belong to an "Open in Fearless" that may still be
    /// importing; `KeystoreImportService` removes those itself once it has read them.
    static let inboxMinimumAge: TimeInterval = 60 * 60

    /// Removes secret files that earlier runs or earlier versions left behind:
    /// export directories, Google Drive backup intermediates named after an address,
    /// and keystore files other apps handed over through the Inbox more than an hour ago.
    @discardableResult
    static func removeLeftovers(
        fileManager: FileManager = .default,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        inboxDirectory: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Inbox", isDirectory: true),
        now: Date = Date()
    ) -> Int {
        var removed = 0

        let temporaryItems = (try? fileManager.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil
        )) ?? []

        for item in temporaryItems {
            let name = item.lastPathComponent
            let isExportDirectory = name.hasPrefix(directoryPrefix) || name.hasPrefix(legacyJsonDirectoryPrefix)
            if isExportDirectory || isAddressNamedKeystore(name) {
                if (try? fileManager.removeItem(at: item)) != nil {
                    removed += 1
                }
            }
        }

        if let inboxDirectory {
            let inboxItems = (try? fileManager.contentsOfDirectory(
                at: inboxDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )) ?? []
            for item in inboxItems {
                let modified = (try? fileManager.attributesOfItem(atPath: item.path))?[.modificationDate] as? Date
                guard let modified, now.timeIntervalSince(modified) >= inboxMinimumAge else {
                    continue
                }
                if (try? fileManager.removeItem(at: item)) != nil {
                    removed += 1
                }
            }
        }

        return removed
    }

    /// `<SS58 address>.json` or `<0x EVM address>.json`, as the Drive backup wrote them.
    static func isAddressNamedKeystore(_ name: String) -> Bool {
        guard name.hasSuffix(".json") else {
            return false
        }

        let stem = String(name.dropLast(".json".count))
        let base58 = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        let hex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")

        if stem.hasPrefix("0x"), stem.count == 42 {
            return String(stem.dropFirst(2)).unicodeScalars.allSatisfy { hex.contains($0) }
        }

        return (40 ... 60).contains(stem.count) && stem.unicodeScalars.allSatisfy { base58.contains($0) }
    }
}

// MARK: - Explicit wallet removal

/// Removes the Keychain secrets of wallets the user explicitly removes ("Forget wallet",
/// logout). Before 4.2.1 those flows deleted only the wallet row, so the seed stayed on
/// the phone and later appeared in the emergency export.
///
/// Only tags that provably belong to a removed wallet are touched: the exact tags this
/// app writes for the wallet and its chain accounts, plus `<metaId><lowercase hex><suffix>`
/// tags of chain accounts that were replaced later. A tag that another stored wallet's
/// identifier could also explain is kept. Keys whose wallet row disappeared for any other
/// reason are never touched here; they stay recoverable through the encrypted export.
///
/// A wallet that was never backed up keeps its keys even when removed: erasing them would
/// make a mistaken removal permanent. Those keys stay reachable only through the
/// PIN-gated, password-encrypted emergency export.
final class WalletSecretEraser {
    private let keystore: KeystoreProtocol
    private let storedTags: () throws -> [String]

    init(
        keystore: KeystoreProtocol = Keychain(),
        storedTags: @escaping () throws -> [String] = EmergencyWalletMaterialReader.walletTags
    ) {
        self.keystore = keystore
        self.storedTags = storedTags
    }

    /// Call only after the wallet rows were deleted successfully.
    /// - Returns: the number of Keychain items removed.
    @discardableResult
    func eraseSecrets(of removed: [MetaAccountModel], remainingMetaIds: Set<String>) -> Int {
        // Enumeration failing must not stop the exact tags from being removed.
        let stored = (try? storedTags()) ?? []
        let others = remainingMetaIds.filter { !$0.isEmpty }
        var candidates = Set<String>()

        for wallet in removed {
            let metaId = wallet.metaId
            guard wallet.hasBackup, !metaId.isEmpty, !others.contains(metaId) else {
                continue
            }

            let accountIds: [AccountId?] = [nil] + wallet.chainAccounts.map { Optional($0.accountId) }
            for accountId in accountIds {
                let middle = accountId?.toHex() ?? ""
                for suffix in EmergencyWalletMaterialReader.walletSuffixes {
                    candidates.insert(metaId + middle + suffix)
                }
            }

            for tag in stored where Self.tag(tag, belongsTo: metaId) {
                candidates.insert(tag)
            }
        }

        var erased = 0
        for tag in candidates.sorted() where !others.contains(where: { tag.hasPrefix($0) }) {
            do {
                guard try keystore.checkKey(for: tag) else {
                    continue
                }
                try keystore.deleteKey(for: tag)
                erased += 1
            } catch {
                continue
            }
        }

        return erased
    }

    static func tag(_ tag: String, belongsTo metaId: String) -> Bool {
        guard !metaId.isEmpty, tag.hasPrefix(metaId) else {
            return false
        }

        let rest = tag.dropFirst(metaId.count)
        for suffix in EmergencyWalletMaterialReader.walletSuffixes where rest.hasSuffix(suffix) {
            let middle = rest.dropLast(suffix.count)
            if middle.isEmpty {
                return true
            }

            let isLowercaseHex = middle.unicodeScalars.allSatisfy { scalar in
                ("0" ... "9").contains(scalar) || ("a" ... "f").contains(scalar)
            }
            if isLowercaseHex, middle.count % 2 == 0, middle.count <= 132 {
                return true
            }
        }

        return false
    }
}
