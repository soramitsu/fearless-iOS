import CryptoKit
import Foundation

/// Durable metadata for a future Keychain/Core Data cohort installer. The
/// record contains key digests and fresh destination IDs, never backup plaintext.
/// It does not authorize an install or make either store write atomic by itself.
enum IOSPortableWalletReceiveJournalRecord {
    enum JournalError: Error, Equatable {
        case invalidRecord
    }

    enum Phase: Int, Codable {
        case staging = 0
        case databaseCommitted = 1
    }

    struct WalletBinding: Codable, Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let metaID: String
        let portableID: Data

        var description: String {
            "WalletBinding(<redacted>)"
        }

        var debugDescription: String {
            description
        }

        var customMirror: Mirror {
            Mirror(self, children: ["summary": description])
        }
    }

    struct KeyProof: Codable, Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let tag: String
        let sha256: Data

        var description: String {
            "KeyProof(<redacted>)"
        }

        var debugDescription: String {
            description
        }

        var customMirror: Mirror {
            Mirror(self, children: ["summary": description])
        }
    }

    struct Record: Codable, Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let schemaVersion: Int
        let transactionID: String
        let semanticSHA256: Data
        let selectedIndex: Int
        let wallets: [WalletBinding]
        let keys: [KeyProof]
        let phase: Phase

        var description: String {
            "IOSPortableWalletReceiveJournalRecord.Record(<redacted>)"
        }

        var debugDescription: String {
            description
        }

        var customMirror: Mirror {
            Mirror(self, children: ["summary": description])
        }
    }

    enum RecoveryDisposition: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        case verifyStagedKeysForRemoval([String])
        case verifyCommittedCohort
        case quarantine

        var description: String {
            "RecoveryDisposition(<redacted>)"
        }

        var debugDescription: String {
            description
        }

        var customMirror: Mirror {
            Mirror(self, children: ["summary": description])
        }
    }

    enum DatabaseObservation {
        case unavailable
        case available(Set<String>)
    }

    enum KeychainObservation {
        case unavailable
        case available([String: Data])
    }

    static let schemaVersion = 1
    static let maximumBytes = 2 * 1024 * 1024
    static let maximumKeys = 4096

    static func encode(_ record: Record) throws -> Data {
        try validate(record)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let encoded = try? encoder.encode(record), encoded.count <= maximumBytes else {
            throw JournalError.invalidRecord
        }
        return encoded
    }

    static func decode(_ encoded: Data) throws -> Record {
        guard !encoded.isEmpty, encoded.count <= maximumBytes,
              let record = try? JSONDecoder().decode(Record.self, from: encoded),
              try encode(record) == encoded else {
            throw JournalError.invalidRecord
        }
        return record
    }

    /// The journal identifies one canonical plaintext semantic cohort, in
    /// source order. A receiving installer must verify this before staging.
    static func verifySemanticMaterial(_ encoded: Data, for record: Record) throws {
        try validate(record)
        guard Data(SHA256.hash(data: encoded)) == record.semanticSHA256,
              var snapshot = try? IOSPortableWalletSemanticMaterial.decode(encoded) else {
            throw JournalError.invalidRecord
        }
        defer { snapshot.clearSecrets() }
        guard snapshot.wallets.count == record.wallets.count,
              snapshot.selectedIndex == record.selectedIndex,
              zip(snapshot.wallets, record.wallets).allSatisfy({ pair in
                  Data(pair.0.portableID) == pair.1.portableID
              }),
              try IOSPortableWalletSemanticMaterial.encode(snapshot) == encoded else {
            throw JournalError.invalidRecord
        }
    }

    /// The caller supplies only the local IDs in this journal and hashes of
    /// observed staged Keychain items. An unavailable or locked store must be
    /// reported as unavailable, never as an empty collection. A cleanup result
    /// is a candidate: the caller must prove these tags were absent before
    /// staging. The complete Core Data after-image must be checked before
    /// clearing a committed journal. Partial state is always quarantined.
    static func recoveryDisposition(
        for record: Record,
        database: DatabaseObservation,
        keychain: KeychainObservation
    ) throws -> RecoveryDisposition {
        try validate(record)
        guard case let .available(presentJournalWalletIDs) = database,
              case let .available(observedKeySHA256) = keychain else {
            return .quarantine
        }
        let expectedWalletIDs = Set(record.wallets.map(\.metaID))
        let expectedKeys = Dictionary(uniqueKeysWithValues: record.keys.map { ($0.tag, $0.sha256) })
        guard presentJournalWalletIDs.isSubset(of: expectedWalletIDs),
              Set(observedKeySHA256.keys).isSubset(of: Set(expectedKeys.keys)),
              observedKeySHA256.allSatisfy({ expectedKeys[$0.key] == $0.value }) else {
            return .quarantine
        }
        if presentJournalWalletIDs.isEmpty, record.phase == .staging {
            return .verifyStagedKeysForRemoval(observedKeySHA256.keys.sorted())
        }
        if presentJournalWalletIDs == expectedWalletIDs,
           observedKeySHA256.count == expectedKeys.count {
            return .verifyCommittedCohort
        }
        return .quarantine
    }

    private static func validate(_ record: Record) throws {
        guard record.schemaVersion == schemaVersion,
              isCanonicalV4UUID(record.transactionID),
              record.semanticSHA256.count == 32,
              (1 ... IOSPortableWalletSemanticMaterial.maxWallets).contains(record.wallets.count),
              record.wallets.indices.contains(record.selectedIndex),
              record.keys.count <= maximumKeys else {
            throw JournalError.invalidRecord
        }
        var walletIDs = Set<String>()
        var portableIDs = Set<Data>()
        for wallet in record.wallets {
            guard isCanonicalV4UUID(wallet.metaID),
                  walletIDs.insert(wallet.metaID).inserted,
                  wallet.portableID.count == 16,
                  wallet.portableID.contains(where: { $0 != 0 }),
                  portableIDs.insert(wallet.portableID).inserted else {
                throw JournalError.invalidRecord
            }
        }
        var priorTag: String?
        for key in record.keys {
            guard key.sha256.count == 32,
                  key.tag.utf8.count <= 512,
                  isOwnedKeyTag(key.tag, walletIDs: walletIDs),
                  priorTag.map({ $0 < key.tag }) ?? true else {
                throw JournalError.invalidRecord
            }
            priorTag = key.tag
        }
    }

    private static func isCanonicalV4UUID(_ value: String) -> Bool {
        guard let uuid = UUID(uuidString: value),
              uuid.uuidString == value || uuid.uuidString.lowercased() == value,
              value.count == 36 else { return false }
        let characters = Array(value)
        return characters[14] == "4" && "89ab".contains(String(characters[19]).lowercased())
    }

    private static func isOwnedKeyTag(_ tag: String, walletIDs: Set<String>) -> Bool {
        let scopedSuffixes = [
            "-substrateSecretKey", "-ethereumSecretKey", "-tonSecretKey",
            "-entropy", "-substrateSeed", "-ethereumSeed",
            "-substrateDeriv", "-ethereumDeriv"
        ]
        for walletID in walletIDs where tag.hasPrefix(walletID) {
            let remainder = String(tag.dropFirst(walletID.count))
            if scopedSuffixes.contains(remainder) || remainder == "-universalWalletSecretSource" {
                return true
            }
            for suffix in scopedSuffixes where remainder.hasSuffix(suffix) {
                let accountHex = remainder.dropLast(suffix.count)
                let bytes = accountHex.utf8
                if (40 ... 256).contains(bytes.count), bytes.count.isMultiple(of: 2),
                   bytes.allSatisfy({ (48 ... 57).contains($0) || (97 ... 102).contains($0) }) {
                    return true
                }
            }
        }
        return false
    }
}
