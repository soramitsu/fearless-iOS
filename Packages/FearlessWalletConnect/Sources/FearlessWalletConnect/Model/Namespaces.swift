import Foundation

/// What a proposal asks for in one namespace, or in one chain when its key is a chain id (CAIP-25).
public struct ProposalNamespace: Hashable, Sendable, Codable {
    public let chains: [Blockchain]?
    public let methods: Set<String>
    public let events: Set<String>

    public init(chains: [Blockchain]? = nil, methods: Set<String>, events: Set<String>) {
        self.chains = chains
        self.methods = methods
        self.events = events
    }

    var json: JSONValue {
        var object: [String: JSONValue] = [
            "methods": .array(methods.sorted().map(JSONValue.string)),
            "events": .array(events.sorted().map(JSONValue.string))
        ]
        if let chains {
            object["chains"] = .array(chains.map { .string($0.absoluteString) })
        }
        return .object(object)
    }

    /// The chains this entry covers: its list, or the chain its key names.
    func coveredChains(key: String) -> [Blockchain] {
        if let chains {
            return chains
        }
        return Blockchain(key).map { [$0] } ?? []
    }
}

/// What a session grants in one namespace: CAIP-10 accounts and the methods and events the dApp may use.
public struct SessionNamespace: Hashable, Sendable, Codable {
    public var chains: [Blockchain]?
    public var accounts: [Account]
    public var methods: Set<String>
    public var events: Set<String>

    public init(chains: [Blockchain]? = nil, accounts: [Account], methods: Set<String>, events: Set<String>) {
        self.chains = chains
        self.accounts = accounts
        self.methods = methods
        self.events = events
    }

    var json: JSONValue {
        var object: [String: JSONValue] = [
            "accounts": .array(accounts.map { .string($0.absoluteString) }),
            "methods": .array(methods.sorted().map(JSONValue.string)),
            "events": .array(events.sorted().map(JSONValue.string))
        ]
        if let chains {
            object["chains"] = .array(chains.map { .string($0.absoluteString) })
        }
        return .object(object)
    }
}

public enum AutoNamespacesError: Error, Equatable, LocalizedError {
    case requiredChainsNotSatisfied
    case requiredAccountsNotSatisfied
    case requiredMethodsNotSatisfied
    case requiredEventsNotSatisfied
    case emptySessionNamespacesForbidden

    public var errorDescription: String? {
        switch self {
        case .requiredChainsNotSatisfied:
            return "The wallet does not support every chain the app requires."
        case .requiredAccountsNotSatisfied:
            return "The wallet has no account on a chain the app requires."
        case .requiredMethodsNotSatisfied:
            return "The wallet does not support every method the app requires."
        case .requiredEventsNotSatisfied:
            return "The wallet does not support every event the app requires."
        case .emptySessionNamespacesForbidden:
            return "Nothing the app asked for can be granted."
        }
    }
}

/// Builds the namespaces a wallet grants for a proposal, from what the wallet supports (CAIP-25).
///
/// Every required entry must be met in full: all its chains supported, all its methods and events supported, and an
/// account on at least one of its chains. Optional entries are granted where they overlap with what the wallet
/// supports and grant at least one method. Entries of one namespace merge into one session namespace.
public enum AutoNamespaces {
    public static func build(
        sessionProposal: Session.Proposal,
        chains: [Blockchain],
        methods: [String],
        events: [String],
        accounts: [Account]
    ) throws -> [String: SessionNamespace] {
        let supportedChains = Set(chains)
        let supportedMethods = Set(methods)
        let supportedEvents = Set(events)
        let uniqueAccounts = accounts.orderedUnique()
        var result: [String: SessionNamespace] = [:]

        for key in sessionProposal.requiredNamespaces.keys.sorted() {
            guard let entry = sessionProposal.requiredNamespaces[key] else {
                continue
            }
            let entryChains = entry.coveredChains(key: key)
            guard !entryChains.isEmpty, entryChains.allSatisfy(supportedChains.contains) else {
                throw AutoNamespacesError.requiredChainsNotSatisfied
            }
            guard entry.methods.isSubset(of: supportedMethods) else {
                throw AutoNamespacesError.requiredMethodsNotSatisfied
            }
            guard entry.events.isSubset(of: supportedEvents) else {
                throw AutoNamespacesError.requiredEventsNotSatisfied
            }
            let grantedAccounts = uniqueAccounts.filter { entryChains.contains($0.blockchain) }
            guard !grantedAccounts.isEmpty else {
                throw AutoNamespacesError.requiredAccountsNotSatisfied
            }

            merge(
                into: &result,
                key: namespaceKey(for: key),
                SessionNamespace(
                    chains: entryChains,
                    accounts: grantedAccounts,
                    methods: entry.methods,
                    events: entry.events
                )
            )
        }

        for key in (sessionProposal.optionalNamespaces ?? [:]).keys.sorted() {
            guard let entry = sessionProposal.optionalNamespaces?[key] else {
                continue
            }
            let entryChains = entry.coveredChains(key: key).filter(supportedChains.contains)
            let grantedMethods = entry.methods.intersection(supportedMethods)
            guard !entryChains.isEmpty, !grantedMethods.isEmpty else {
                continue
            }

            merge(
                into: &result,
                key: namespaceKey(for: key),
                SessionNamespace(
                    chains: entryChains,
                    accounts: uniqueAccounts.filter { entryChains.contains($0.blockchain) },
                    methods: grantedMethods,
                    events: entry.events.intersection(supportedEvents)
                )
            )
        }

        guard !result.isEmpty else {
            throw AutoNamespacesError.emptySessionNamespacesForbidden
        }
        return result
    }

    /// A chain-scoped key (`eip155:1`) is granted under its namespace (`eip155`).
    private static func namespaceKey(for key: String) -> String {
        Blockchain(key)?.namespace ?? key
    }

    private static func merge(into result: inout [String: SessionNamespace], key: String, _ namespace: SessionNamespace) {
        guard var existing = result[key] else {
            result[key] = namespace
            return
        }
        existing.chains = (existing.chains ?? []).orderedUnion(namespace.chains ?? [])
        existing.accounts = existing.accounts.orderedUnion(namespace.accounts)
        existing.methods.formUnion(namespace.methods)
        existing.events.formUnion(namespace.events)
        result[key] = existing
    }
}

extension Array where Element: Hashable {
    func orderedUnique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }

    func orderedUnion(_ other: [Element]) -> [Element] {
        (self + other).orderedUnique()
    }
}
