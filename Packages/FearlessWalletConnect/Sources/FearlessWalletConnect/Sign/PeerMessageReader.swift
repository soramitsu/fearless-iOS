import Foundation

/// Reads what peers send. Everything from the relay is untrusted: anything malformed or oversized is refused, never
/// repaired, and nothing beyond the protocol's fields is kept.
enum PeerMessageReader {
    static let maxNamespaces = 32
    static let maxItems = 512
    static let maxItemLength = 512
    static let maxURLLength = 2048
    static let maxProperties = 32
    static let maxPropertyLength = 8192

    static func strings(_ value: JSONValue?, check: (String) -> Bool = { _ in true }) -> [String]? {
        guard let value else {
            return []
        }
        guard let array = value.arrayValue, array.count <= maxItems else {
            return nil
        }
        var result: [String] = []
        for item in array {
            guard let string = item.stringValue, string.utf8.count <= maxItemLength, check(string) else {
                return nil
            }
            result.append(string)
        }
        return result
    }

    static func metadata(_ value: JSONValue?) -> AppMetadata? {
        guard
            let object = value?.objectValue,
            let name = object["name"]?.stringValue, name.utf8.count <= 256,
            let url = object["url"]?.stringValue, url.utf8.count <= maxURLLength
        else {
            return nil
        }

        var description = ""
        if let value = object["description"], !value.isNull {
            guard let string = value.stringValue, string.utf8.count <= 4096 else {
                return nil
            }
            description = string
        }

        var icons: [String] = []
        if let value = object["icons"], !value.isNull {
            guard let array = value.arrayValue, array.count <= 16 else {
                return nil
            }
            for icon in array {
                guard let string = icon.stringValue, string.utf8.count <= maxURLLength else {
                    return nil
                }
                icons.append(string)
            }
        }

        let verifyUrl = object["verifyUrl"]?.stringValue.flatMap { $0.utf8.count <= maxURLLength ? $0 : nil }
        var redirect: AppMetadata.Redirect?
        if let redirectObject = object["redirect"]?.objectValue {
            let native = redirectObject["native"]?.stringValue.flatMap { $0.utf8.count <= maxURLLength ? $0 : nil }
            let universal = redirectObject["universal"]?.stringValue.flatMap { $0.utf8.count <= maxURLLength ? $0 : nil }
            redirect = AppMetadata.Redirect(native: native, universal: universal, linkMode: redirectObject["linkMode"]?.boolValue)
        }

        return AppMetadata(
            name: name,
            description: description,
            url: url,
            icons: icons,
            verifyUrl: verifyUrl,
            redirect: redirect
        )
    }

    static func participant(_ value: JSONValue?) -> StoredParticipant? {
        guard
            let publicKey = value?["publicKey"]?.stringValue, Hex.isKey(publicKey),
            let metadata = metadata(value?["metadata"])
        else {
            return nil
        }
        return StoredParticipant(publicKey: publicKey, metadata: metadata)
    }

    static func relayProtocol(_ value: JSONValue?) -> String? {
        guard let name = value?["protocol"]?.stringValue, !name.isEmpty, name.utf8.count <= 64 else {
            return nil
        }
        return name
    }

    /// Missing namespaces are empty; anything malformed is `nil`.
    static func proposalNamespaces(_ value: JSONValue?) -> [String: ProposalNamespace]? {
        guard let value, !value.isNull else {
            return [:]
        }
        guard let object = value.objectValue, object.count <= maxNamespaces else {
            return nil
        }
        var result: [String: ProposalNamespace] = [:]
        for (key, entry) in object {
            guard
                CAIP.isNamespaceKey(key),
                entry.objectValue != nil,
                let methods = strings(entry["methods"]),
                let events = strings(entry["events"])
            else {
                return nil
            }
            var chains: [Blockchain]?
            if let chainValue = entry["chains"], !chainValue.isNull {
                guard let list = strings(chainValue, check: { Blockchain($0) != nil }) else {
                    return nil
                }
                chains = list.compactMap(Blockchain.init)
            }
            result[key] = ProposalNamespace(chains: chains, methods: Set(methods), events: Set(events))
        }
        return result
    }

    enum Properties {
        case absent
        case valid([String: String])
        case invalid
    }

    static func properties(_ value: JSONValue?) -> Properties {
        guard let value, !value.isNull else {
            return .absent
        }
        guard let object = value.objectValue, object.count <= maxProperties else {
            return .invalid
        }
        var result: [String: String] = [:]
        for (key, entry) in object {
            guard key.utf8.count <= 256, let string = entry.stringValue, string.utf8.count <= maxPropertyLength else {
                return .invalid
            }
            result[key] = string
        }
        return .valid(result)
    }

    /// Checks namespaces the wallet is about to grant: every key a namespace or chain, every account on a chain of
    /// its key.
    static func isValidGrant(_ namespaces: [String: SessionNamespace]) -> Bool {
        guard !namespaces.isEmpty, namespaces.count <= maxNamespaces else {
            return false
        }
        return namespaces.allSatisfy { key, namespace in
            guard CAIP.isNamespaceKey(key), !namespace.accounts.isEmpty else {
                return false
            }
            let keyChain = Blockchain(key)
            return namespace.accounts.allSatisfy { account in
                keyChain.map { $0 == account.blockchain } ?? (account.namespace == key)
            }
        }
    }

    /// Whether granted namespaces cover everything a proposal required: an account on each required chain, and each
    /// required method and event.
    static func covers(required: [String: ProposalNamespace], granted: [String: SessionNamespace]) -> Bool {
        required.allSatisfy { key, need in
            let chains = need.coveredChains(key: key)
            let candidates = [granted[key], Blockchain(key).flatMap { granted[$0.namespace] }].compactMap { $0 }
            guard !chains.isEmpty, !candidates.isEmpty else {
                return false
            }
            let grantedChains = Set(candidates.flatMap { $0.accounts.map(\.blockchain) })
            let methods = candidates.reduce(into: Set<String>()) { $0.formUnion($1.methods) }
            let events = candidates.reduce(into: Set<String>()) { $0.formUnion($1.events) }
            return chains.allSatisfy(grantedChains.contains)
                && need.methods.isSubset(of: methods)
                && need.events.isSubset(of: events)
        }
    }
}
