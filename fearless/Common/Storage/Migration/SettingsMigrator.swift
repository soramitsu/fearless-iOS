import Foundation
import SoraKeystore

protocol SettingsMigrating: AnyObject {
    func switchVersion() throws
    func value(for key: String) -> Any?
    func remove(key: String)
    func set(value: Any, for key: String)
    func finalize() throws
}

enum SettingsMigratingError: Error {
    case nextVersionMissing
    case destinationNotReached
}

class SettingsMigrator {
    let sourceVersion: UserStorageVersion
    let destinationVersion: UserStorageVersion
    private(set) var settings: SettingsManagerProtocol

    private(set) var currentVersion: UserStorageVersion

    private(set) var keysToRemoveOnFinalize: Set<String> = []
    private(set) var tempKeystore: [String: Any] = [:]

    init(
        sourceVersion: UserStorageVersion,
        destinationVersion: UserStorageVersion,
        settings: SettingsManagerProtocol
    ) {
        self.sourceVersion = sourceVersion
        self.destinationVersion = destinationVersion
        currentVersion = sourceVersion
        self.settings = settings
    }
}

extension SettingsMigrator: SettingsMigrating {
    func switchVersion() throws {
        guard let nextVersion = currentVersion.nextVersion() else {
            throw KeystoreMigratingError.nextVersionMissing
        }

        currentVersion = nextVersion
    }

    func value(for key: String) -> Any? {
        if sourceVersion.nextVersion() == currentVersion {
            return settings.anyValue(for: key)
        } else {
            return tempKeystore[key]
        }
    }

    func remove(key: String) {
        tempKeystore[key] = nil

        keysToRemoveOnFinalize.insert(key)
    }

    func set(value: Any, for key: String) {
        tempKeystore[key] = value
    }

    func finalize() throws {
        guard currentVersion == destinationVersion else {
            throw KeystoreMigratingError.destinationNotReached
        }

        keysToRemoveOnFinalize.forEach { key in
            settings.removeValue(for: key)
        }

        for (key, value) in tempKeystore {
            settings.set(anyValue: value, for: key)
        }
    }
}
