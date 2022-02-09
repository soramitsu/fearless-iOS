import Foundation
import SoraKeystore

protocol KeystoreMigrating: AnyObject {
    func switchVersion() throws
    func fetchKey(for identifier: String) -> Data?
    func deleteKey(for identifier: String)
    func save(key: Data, for identifier: String)
    func finalize() throws
}

enum KeystoreMigratingError: Error {
    case nextVersionMissing
    case destinationNotReached
}

class KeystoreMigrator {
    let sourceVersion: UserStorageVersion
    let destinationVersion: UserStorageVersion
    let keystore: KeystoreProtocol

    private(set) var currentVersion: UserStorageVersion

    private(set) var identifiersToRemoveOnFinalize: Set<String> = []
    private(set) var tempKeystore: [String: Data] = [:]

    init(
        sourceVersion: UserStorageVersion,
        destinationVersion: UserStorageVersion,
        keystore: KeystoreProtocol
    ) {
        self.sourceVersion = sourceVersion
        self.destinationVersion = destinationVersion
        currentVersion = sourceVersion
        self.keystore = keystore
    }
}

extension KeystoreMigrator: KeystoreMigrating {
    func switchVersion() throws {
        guard let nextVersion = currentVersion.nextVersion() else {
            throw KeystoreMigratingError.nextVersionMissing
        }

        currentVersion = nextVersion
    }

    func fetchKey(for identifier: String) -> Data? {
        if sourceVersion.nextVersion() == currentVersion {
            return try? keystore.fetchKey(for: identifier)
        } else {
            return tempKeystore[identifier]
        }
    }

    func deleteKey(for identifier: String) {
        tempKeystore[identifier] = nil

        identifiersToRemoveOnFinalize.insert(identifier)
    }

    func save(key: Data, for identifier: String) {
        tempKeystore[identifier] = key
    }

    func finalize() throws {
        guard currentVersion == destinationVersion else {
            throw KeystoreMigratingError.destinationNotReached
        }

        try identifiersToRemoveOnFinalize.forEach { identifier in
            try keystore.deleteKeyIfExists(for: identifier)
        }

        for (identifier, key) in tempKeystore {
            try keystore.saveKey(key, with: identifier)
        }
    }
}
