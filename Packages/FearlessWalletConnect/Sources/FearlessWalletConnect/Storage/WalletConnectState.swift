import Foundation

/// A peer's public key and metadata.
struct StoredParticipant: Codable, Hashable {
    let publicKey: String
    let metadata: AppMetadata
}

struct StoredPairing: Codable, Hashable {
    let topic: String
    /// Seconds since 1970.
    var expiry: Int64
    var relayProtocol: String
    /// A pairing turns active once a proposal arrived on it; an inactive one lives only minutes.
    var active: Bool
    var peerMetadata: AppMetadata?
    var methods: [String]?
    /// Set when the pairing came from an earlier SDK's records, which are removed with it.
    var importedFrom: String?
}

struct StoredSession: Codable, Hashable {
    let topic: String
    let pairingTopic: String
    let relayProtocol: String
    /// Seconds since 1970.
    var expiry: Int64
    /// Whether the dApp confirmed the settlement. Requests are refused before.
    var acknowledged: Bool
    /// The public key of the wallet side; Fearless is the wallet when it is `selfParticipant.publicKey`.
    let controller: String
    var namespaces: [String: SessionNamespace]
    let requiredNamespaces: [String: ProposalNamespace]
    let optionalNamespaces: [String: ProposalNamespace]?
    let sessionProperties: [String: String]?
    let selfParticipant: StoredParticipant
    let peer: StoredParticipant
    var importedFrom: String?

    var isWalletSession: Bool {
        controller == selfParticipant.publicKey
    }

    var publicSession: Session {
        Session(
            topic: topic,
            pairingTopic: pairingTopic,
            peer: peer.metadata,
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces,
            namespaces: namespaces,
            sessionProperties: sessionProperties,
            expiryDate: Date(timeIntervalSince1970: TimeInterval(expiry))
        )
    }

    /// Whether the session lets the dApp call `method` on `chain`: a namespace for the chain (or its namespace) that
    /// has an account on it and lists the method.
    func permits(method: String, on chain: Blockchain) -> Bool {
        [chain.namespace, chain.absoluteString].contains { key in
            guard let namespace = namespaces[key] else {
                return false
            }
            return namespace.methods.contains(method) && namespace.accounts.contains { $0.blockchain == chain }
        }
    }

    func grants(chain: Blockchain) -> Bool {
        [chain.namespace, chain.absoluteString].contains { key in
            namespaces[key]?.accounts.contains { $0.blockchain == chain } == true
        }
    }
}

struct StoredProposal: Codable, Hashable {
    let id: Int64
    let pairingTopic: String
    /// Seconds since 1970.
    let expiry: Int64
    let relayProtocol: String
    let proposer: StoredParticipant
    let requiredNamespaces: [String: ProposalNamespace]
    let optionalNamespaces: [String: ProposalNamespace]?
    let sessionProperties: [String: String]?

    var publicProposal: Session.Proposal {
        Session.Proposal(
            id: id,
            pairingTopic: pairingTopic,
            proposer: proposer.metadata,
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces,
            sessionProperties: sessionProperties,
            expiryDate: Date(timeIntervalSince1970: TimeInterval(expiry))
        )
    }
}

/// A dApp request waiting for an answer, until it is answered or expires.
struct StoredRequest: Codable, Hashable {
    let id: Int64
    let topic: String
    let expiry: Int64
}

struct SeenMessage: Codable, Hashable {
    let hash: String
    let at: Int64
}

struct LegacyImportSummary: Codable, Hashable {
    var at: Int64
    var sessions: Int
    var pairings: Int
    var clientIdentity: Bool
}

/// Everything the client keeps apart from keys. It is written whole.
struct WalletConnectState: Codable, Equatable {
    static let currentVersion = 1

    var version = WalletConnectState.currentVersion
    var pairings: [StoredPairing] = []
    var sessions: [StoredSession] = []
    var proposals: [StoredProposal] = []
    var requests: [StoredRequest] = []
    /// The settlement request sent for a session, by topic, until the dApp acknowledges it.
    var settlements: [String: Int64] = [:]
    /// Hashes of handled messages, so a redelivered message is handled once.
    var seen: [SeenMessage] = []
    /// Topics this client ended. An earlier SDK's record of one is never imported again.
    var forgottenTopics: [String] = []
    var legacyImport: LegacyImportSummary?

    var liveTopics: [String] {
        (pairings.map(\.topic) + sessions.map(\.topic)).orderedUnique()
    }
}

/// The client's secrets: its relay identity and the symmetric key of each topic, all hex.
struct WalletConnectSecrets: Codable, Equatable {
    var clientSeed: String
    var keys: [String: String]
}

enum WalletConnectCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
