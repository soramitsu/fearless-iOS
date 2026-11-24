import Foundation

/// A session in which Fearless is the wallet: what the dApp may ask for and until when.
public struct Session: Hashable, Sendable {
    public let topic: String
    public let pairingTopic: String
    public let peer: AppMetadata
    public let requiredNamespaces: [String: ProposalNamespace]
    public let optionalNamespaces: [String: ProposalNamespace]?
    public let namespaces: [String: SessionNamespace]
    public let sessionProperties: [String: String]?
    public let expiryDate: Date

    public init(
        topic: String,
        pairingTopic: String,
        peer: AppMetadata,
        requiredNamespaces: [String: ProposalNamespace],
        optionalNamespaces: [String: ProposalNamespace]?,
        namespaces: [String: SessionNamespace],
        sessionProperties: [String: String]?,
        expiryDate: Date
    ) {
        self.topic = topic
        self.pairingTopic = pairingTopic
        self.peer = peer
        self.requiredNamespaces = requiredNamespaces
        self.optionalNamespaces = optionalNamespaces
        self.namespaces = namespaces
        self.sessionProperties = sessionProperties
        self.expiryDate = expiryDate
    }

    /// Every account the session grants.
    public var accounts: [Account] {
        namespaces.keys.sorted().flatMap { namespaces[$0]?.accounts ?? [] }
    }

    /// A dApp proposal waiting for the person's decision.
    public struct Proposal: Hashable, Sendable {
        /// The proposal's JSON-RPC id; approval and refusal name it.
        public let id: Int64
        public let pairingTopic: String
        public let proposer: AppMetadata
        public let requiredNamespaces: [String: ProposalNamespace]
        public let optionalNamespaces: [String: ProposalNamespace]?
        public let sessionProperties: [String: String]?
        public let expiryDate: Date

        public init(
            id: Int64,
            pairingTopic: String,
            proposer: AppMetadata,
            requiredNamespaces: [String: ProposalNamespace],
            optionalNamespaces: [String: ProposalNamespace]?,
            sessionProperties: [String: String]?,
            expiryDate: Date
        ) {
            self.id = id
            self.pairingTopic = pairingTopic
            self.proposer = proposer
            self.requiredNamespaces = requiredNamespaces
            self.optionalNamespaces = optionalNamespaces
            self.sessionProperties = sessionProperties
            self.expiryDate = expiryDate
        }
    }
}

/// A dApp's request in a session: a method on one chain.
public struct Request: Hashable, Sendable {
    public let id: Int64
    public let topic: String
    public let method: String
    public let params: AnyCodable
    public let chainId: Blockchain
    /// Seconds since 1970 after which the dApp no longer waits for an answer.
    public let expiryTimestamp: UInt64?

    public init(
        id: Int64 = Request.makeIdentifier(),
        topic: String,
        method: String,
        params: AnyCodable,
        chainId: Blockchain,
        expiryTimestamp: UInt64? = nil
    ) {
        self.id = id
        self.topic = topic
        self.method = method
        self.params = params
        self.chainId = chainId
        self.expiryTimestamp = expiryTimestamp
    }

    private static let identifiers = RPCIdentifierGenerator()

    public static func makeIdentifier() -> Int64 {
        identifiers.next(now: Date())
    }
}

/// Where the Verify service says a proposal or request came from, against the URL the dApp claims.
public struct VerifyContext: Hashable, Sendable {
    public enum Validation: String, Hashable, Sendable {
        case unknown
        case valid
        case invalid
        case scam
    }

    public let origin: String
    public let validation: Validation
    public let verifyUrl: String
    public let isScam: Bool

    public init(origin: String, validation: Validation, verifyUrl: String, isScam: Bool = false) {
        self.origin = origin
        self.validation = validation
        self.verifyUrl = verifyUrl
        self.isScam = isScam
    }
}

/// Why the wallet refuses a proposal. The codes are fixed by the Sign protocol, because dApps compare them.
public enum RejectionReason: Hashable, Sendable {
    case userRejected
    case unsupportedChains
    case unsupportedMethods
    case unsupportedAccounts
    case unsupportedEvents

    public var code: Int {
        switch self {
        case .userRejected:
            return 5000
        case .unsupportedChains:
            return 5100
        case .unsupportedMethods:
            return 5101
        case .unsupportedEvents:
            return 5102
        case .unsupportedAccounts:
            return 5103
        }
    }

    public var message: String {
        switch self {
        case .userRejected:
            return "User rejected."
        case .unsupportedChains:
            return "Unsupported chains."
        case .unsupportedMethods:
            return "Unsupported methods."
        case .unsupportedEvents:
            return "Unsupported events."
        case .unsupportedAccounts:
            return "Unsupported accounts."
        }
    }

    public init(_ error: AutoNamespacesError) {
        switch error {
        case .requiredChainsNotSatisfied:
            self = .unsupportedChains
        case .requiredAccountsNotSatisfied, .emptySessionNamespacesForbidden:
            self = .unsupportedAccounts
        case .requiredMethodsNotSatisfied:
            self = .unsupportedMethods
        case .requiredEventsNotSatisfied:
            self = .unsupportedEvents
        }
    }
}
