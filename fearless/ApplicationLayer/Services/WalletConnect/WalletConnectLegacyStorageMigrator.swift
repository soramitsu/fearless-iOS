import Foundation

/// A WalletConnect session that an earlier release kept outside the app group.
struct WalletConnectLegacySession: Codable, Equatable {
    let topic: String
    let peerName: String?
    let peerURL: String?
    let expiryDate: Date?
}

/// App side of the move from the app sandbox into the WalletConnect app group.
///
/// Every public release with WalletConnect (3.0.5 up to 4.0.5 and 4.1.0) used WalletConnectSwiftV2 without an
/// app group: sessions and pairings in `UserDefaults.standard`, keys in the default keychain access group.
/// Reown moves all of it into the group by itself when its stores are first created
/// (`CodableStore.migrateIfNeeded`, `ClientIdStorage.migrateIfNeeded` and `KeychainStorage` on read), which
/// `WalletConnectLegacyStorageContinuityTests` proves against fixtures in the exact layouts those releases
/// wrote, so this type copies nothing. Reown does drop sessions that expired while the old version was
/// installed, so before the SDK is configured this records which legacy sessions existed. The Connections
/// screen uses the record to ask the user, once, to reconnect apps whose sessions did not carry over.
///
/// It only reads the legacy storage and never writes to or deletes from the SDK's keys.
final class WalletConnectLegacyStorageMigrator {
    static let legacySessionsKey = "walletconnect.legacy_sessions.v1"
    static let legacySessionKeyPrefix = "com.walletconnect.sdk.sessionSequences."
    static let groupSessionsMigratedKey = "hasMigratedToGroup_com.walletconnect.sdk.sessionSequences"

    private let legacyDefaults: UserDefaults
    private let groupDefaults: UserDefaults?
    private let logger: LoggerProtocol

    init(
        groupIdentifier: String,
        legacyDefaults: UserDefaults = .standard,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.legacyDefaults = legacyDefaults
        groupDefaults = UserDefaults(suiteName: groupIdentifier)
        self.logger = logger
    }

    init(
        legacyDefaults: UserDefaults,
        groupDefaults: UserDefaults?,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.legacyDefaults = legacyDefaults
        self.groupDefaults = groupDefaults
        self.logger = logger
    }

    /// Must run before the WalletConnect SDK is configured, because the SDK moves the legacy entries away.
    func recordLegacySessionsIfNeeded() {
        guard
            legacyDefaults.object(forKey: Self.legacySessionsKey) == nil,
            groupDefaults?.bool(forKey: Self.groupSessionsMigratedKey) != true
        else {
            return
        }

        let sessions = legacyDefaults.dictionaryRepresentation()
            .compactMap { key, value -> WalletConnectLegacySession? in
                guard key.hasPrefix(Self.legacySessionKeyPrefix), let data = value as? Data else {
                    return nil
                }

                let topic = String(key.dropFirst(Self.legacySessionKeyPrefix.count))
                let record = try? JSONDecoder().decode(LegacySessionRecord.self, from: data)

                return WalletConnectLegacySession(
                    topic: topic,
                    peerName: record?.peerParticipant?.metadata?.name,
                    peerURL: record?.peerParticipant?.metadata?.url,
                    expiryDate: record?.expiryDate
                )
            }
            .sorted { $0.topic < $1.topic }

        do {
            legacyDefaults.set(try JSONEncoder().encode(sessions), forKey: Self.legacySessionsKey)
        } catch {
            logger.error("WalletConnect legacy sessions were not recorded: \(error)")
        }
    }

    func recordedLegacySessions() -> [WalletConnectLegacySession] {
        guard let data = legacyDefaults.data(forKey: Self.legacySessionsKey) else {
            return []
        }

        return (try? JSONDecoder().decode([WalletConnectLegacySession].self, from: data)) ?? []
    }

    /// Legacy sessions that are not active now, either because they expired before the upgrade or because the
    /// SDK could not read them.
    func legacySessionsNeedingReconnect(activeTopics: Set<String>) -> [WalletConnectLegacySession] {
        recordedLegacySessions().filter { !activeTopics.contains($0.topic) }
    }

    func logContinuity(activeTopics: Set<String>) {
        let recorded = recordedLegacySessions()
        guard !recorded.isEmpty else {
            return
        }

        let needingReconnect = legacySessionsNeedingReconnect(activeTopics: activeTopics)
        logger.info(
            "WalletConnect legacy sessions: \(recorded.count) recorded, \(needingReconnect.count) need reconnecting"
        )
    }
}

/// The fields of a WalletConnectSwiftV2 `WCSession` JSON record that the reconnect notice needs.
private struct LegacySessionRecord: Decodable {
    let expiryDate: Date?
    let peerParticipant: LegacySessionParticipant?
}

private struct LegacySessionParticipant: Decodable {
    let metadata: LegacySessionPeerMetadata?
}

private struct LegacySessionPeerMetadata: Decodable {
    let name: String?
    let url: String?
}
