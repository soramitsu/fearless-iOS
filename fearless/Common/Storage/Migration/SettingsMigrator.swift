import Foundation
import SoraKeystore

protocol SettingsMigrating: AnyObject {
    func switchVersion() throws
    func value(for key: String) -> Any?
    func remove(key: String)
    func set(value: Any, for key: String)
    func prepare() throws
    func finalize() throws
}

enum SettingsMigratingError: LocalizedError {
    case destinationNotReached
    case notPrepared
    case unsupportedPendingValues
    case cleanupJournalVerificationFailed
    case invalidCleanupJournal

    var errorDescription: String? {
        switch self {
        case .destinationNotReached:
            return "The settings migration did not reach its destination version"
        case .notPrepared:
            return "The settings cleanup was not prepared before database replacement"
        case .unsupportedPendingValues:
            return "The settings migration contains unsupported pending values"
        case .cleanupJournalVerificationFailed:
            return "Unable to verify the pending settings cleanup"
        case .invalidCleanupJournal:
            return "The pending settings cleanup is invalid"
        }
    }
}

class SettingsMigrator {
    static let pendingCleanupKey =
        "io.fearless.user-storage-migration.pending-settings-cleanup"
    private static let cleanupJournalSchemaVersion = 1
    private static let maximumCleanupJournalBytes = 4096
    private static let cleanupJournalFields: Set<String> = [
        "schemaVersion",
        "sourceVersion",
        "destinationVersion",
        "keysToRemove"
    ]
    private static let allowedCleanupKeys: Set<String> = [
        SettingsKey.selectedAccount.rawValue,
        SettingsKey.selectedConnection.rawValue
    ]

    private struct CleanupJournal: Codable {
        let schemaVersion: Int
        let sourceVersion: String
        let destinationVersion: String
        let keysToRemove: [String]
    }

    let sourceVersion: UserStorageVersion
    let destinationVersion: UserStorageVersion
    private(set) var settings: SettingsManagerProtocol

    private(set) var currentVersion: UserStorageVersion

    private(set) var keysToRemoveOnFinalize: Set<String> = []
    private(set) var tempKeystore: [String: Any] = [:]
    private(set) var isPrepared = false

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

    func prepare() throws {
        guard currentVersion == destinationVersion else {
            throw SettingsMigratingError.destinationNotReached
        }

        // No current user-storage mapping stages settings values. Refuse to
        // cross the database replacement boundary if a future mapping starts
        // doing so without extending the durable journal format first.
        guard tempKeystore.isEmpty else {
            throw SettingsMigratingError.unsupportedPendingValues
        }

        guard !keysToRemoveOnFinalize.isEmpty else {
            isPrepared = true
            return
        }

        let journal = CleanupJournal(
            schemaVersion: Self.cleanupJournalSchemaVersion,
            sourceVersion: sourceVersion.rawValue,
            destinationVersion: destinationVersion.rawValue,
            keysToRemove: keysToRemoveOnFinalize.sorted()
        )
        try Self.validate(journal)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(journal)
        settings.set(value: data, for: Self.pendingCleanupKey)

        guard settings.data(for: Self.pendingCleanupKey) == data else {
            throw SettingsMigratingError
                .cleanupJournalVerificationFailed
        }

        isPrepared = true
    }

    func finalize() throws {
        guard currentVersion == destinationVersion else {
            throw SettingsMigratingError.destinationNotReached
        }

        guard isPrepared else {
            throw SettingsMigratingError.notPrepared
        }

        guard !keysToRemoveOnFinalize.isEmpty else {
            return
        }

        guard settings.data(for: Self.pendingCleanupKey) != nil else {
            throw SettingsMigratingError
                .cleanupJournalVerificationFailed
        }

        try Self.recoverPendingCleanup(
            settings: settings,
            currentVersion: destinationVersion
        )
    }
}

extension SettingsMigrator {
    static func recoverPendingCleanup(
        settings: SettingsManagerProtocol,
        currentVersion: UserStorageVersion
    ) throws {
        guard let storedValue = settings.anyValue(
            for: pendingCleanupKey
        ) else {
            return
        }

        guard let data = storedValue as? Data else {
            throw SettingsMigratingError.invalidCleanupJournal
        }
        try validateEncodedJournalShape(data)

        let journal: CleanupJournal
        do {
            journal = try JSONDecoder().decode(
                CleanupJournal.self,
                from: data
            )
        } catch {
            throw SettingsMigratingError.invalidCleanupJournal
        }

        try validate(journal)

        guard
            let sourceVersion =
            UserStorageVersion(rawValue: journal.sourceVersion),
            let destinationVersion =
            UserStorageVersion(rawValue: journal.destinationVersion)
        else {
            throw SettingsMigratingError.invalidCleanupJournal
        }

        if isVersion(
            currentVersion,
            sameOrNewerThan: destinationVersion
        ) {
            for key in journal.keysToRemove {
                settings.removeValue(for: key)
            }

            guard journal.keysToRemove.allSatisfy({
                settings.anyValue(for: $0) == nil
            }) else {
                throw SettingsMigratingError
                    .cleanupJournalVerificationFailed
            }

            settings.removeValue(for: pendingCleanupKey)
        } else if currentVersion == sourceVersion {
            // Database replacement did not occur. Discard the cleanup intent;
            // the next migration attempt will reconstruct it.
            settings.removeValue(for: pendingCleanupKey)
        } else {
            throw SettingsMigratingError.invalidCleanupJournal
        }
    }

    private static func validate(
        _ journal: CleanupJournal
    ) throws {
        guard
            journal.schemaVersion == cleanupJournalSchemaVersion,
            let sourceVersion =
            UserStorageVersion(rawValue: journal.sourceVersion),
            let destinationVersion =
            UserStorageVersion(rawValue: journal.destinationVersion),
            isVersion(
                destinationVersion,
                sameOrNewerThan: sourceVersion
            ),
            sourceVersion != destinationVersion,
            Set(journal.keysToRemove).count ==
            journal.keysToRemove.count,
            Set(journal.keysToRemove) == allowedCleanupKeys
        else {
            throw SettingsMigratingError.invalidCleanupJournal
        }
    }

    private static func validateEncodedJournalShape(
        _ data: Data
    ) throws {
        guard
            !data.isEmpty,
            data.count <= maximumCleanupJournalBytes,
            let object = try? JSONSerialization.jsonObject(
                with: data,
                options: []
            ) as? [String: Any],
            Set(object.keys) == cleanupJournalFields,
            object["schemaVersion"] is Int,
            object["sourceVersion"] is String,
            object["destinationVersion"] is String,
            object["keysToRemove"] is [String]
        else {
            throw SettingsMigratingError.invalidCleanupJournal
        }

        // JSONSerialization accepts duplicate members and keeps one value.
        // Require every exact ASCII field token once so a duplicate or escaped
        // spelling can never smuggle an alternate cleanup request.
        for field in cleanupJournalFields {
            let token = Data("\"\(field)\"".utf8)
            guard data.nonOverlappingOccurrenceCount(of: token) == 1 else {
                throw SettingsMigratingError.invalidCleanupJournal
            }
        }
    }

    private static func isVersion(
        _ candidate: UserStorageVersion,
        sameOrNewerThan version: UserStorageVersion
    ) -> Bool {
        var current: UserStorageVersion? = version

        while let currentVersion = current {
            if currentVersion == candidate {
                return true
            }

            current = currentVersion.nextVersion()
        }

        return false
    }
}

private extension Data {
    func nonOverlappingOccurrenceCount(of token: Data) -> Int {
        guard !token.isEmpty else {
            return 0
        }

        var count = 0
        var searchStart = startIndex

        while
            searchStart < endIndex,
            let range = range(
                of: token,
                options: [],
                in: searchStart ..< endIndex
            ) {
            count += 1
            searchStart = range.upperBound
        }

        return count
    }
}
