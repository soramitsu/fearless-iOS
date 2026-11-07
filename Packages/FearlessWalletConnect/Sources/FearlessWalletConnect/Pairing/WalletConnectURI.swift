import Foundation

/// A WalletConnect v2 pairing link:
/// `wc:<topic>@2?relay-protocol=irn&symKey=<key>[&expiryTimestamp=<seconds>][&methods=...]`.
public struct WalletConnectURI: Hashable, Sendable, CustomStringConvertible {
    public enum Error: Swift.Error, Equatable {
        /// A version 1 link: that protocol and its bridge servers are gone.
        case retiredVersion
        case invalid(String)
    }

    public let topic: String
    public let symKey: String
    public let relayProtocol: String
    public let relayData: String?
    public let expiryTimestamp: UInt64?
    public let methods: [String]?

    private static let maxLength = 4096

    public init(uriString input: String) throws {
        guard input.utf8.count <= Self.maxLength else {
            throw Error.invalid("pairing link")
        }
        var uri = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard uri.hasPrefix("wc:") else {
            throw Error.invalid("pairing link")
        }
        uri.removeFirst(3)
        if uri.hasPrefix("//") {
            uri.removeFirst(2)
        }

        guard let at = uri.firstIndex(of: "@") else {
            throw Error.invalid("pairing link")
        }
        let topic = uri[..<at].lowercased()
        let rest = uri[uri.index(after: at)...]
        let versionPart: Substring
        let queryPart: Substring?
        if let question = rest.firstIndex(of: "?") {
            versionPart = rest[..<question]
            queryPart = rest[rest.index(after: question)...]
        } else {
            versionPart = rest
            queryPart = nil
        }

        guard !versionPart.isEmpty, versionPart.utf8.allSatisfy({ (0x30 ... 0x39).contains($0) }) else {
            throw Error.invalid("pairing link")
        }
        if versionPart == "1" {
            throw Error.retiredVersion
        }
        guard versionPart == "2" else {
            throw Error.invalid("pairing link version")
        }
        guard Hex.isKey(topic) else {
            throw Error.invalid("pairing topic")
        }

        var components = URLComponents()
        components.percentEncodedQuery = queryPart.map(String.init)
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] where query[item.name] == nil {
            query[item.name] = item.value ?? ""
        }

        let symKey = (query["symKey"] ?? "").lowercased()
        guard Hex.isKey(symKey) else {
            throw Error.invalid("pairing key")
        }

        let relayProtocol = query["relay-protocol"] ?? "irn"
        guard relayProtocol == "irn" else {
            throw Error.invalid("relay protocol")
        }

        var expiryTimestamp: UInt64?
        if let expiry = query["expiryTimestamp"] {
            guard (1 ... 12).contains(expiry.count), let value = UInt64(expiry) else {
                throw Error.invalid("pairing expiry")
            }
            expiryTimestamp = value
        }

        self.topic = topic
        self.symKey = symKey
        self.relayProtocol = relayProtocol
        relayData = query["relay-data"].flatMap { $0.isEmpty ? nil : $0 }
        self.expiryTimestamp = expiryTimestamp
        methods = query["methods"].flatMap { value in
            value.isEmpty ? nil : Array(value.split(separator: ",").prefix(32).map(String.init))
        }
    }

    public init(
        topic: String,
        symKey: String,
        relayProtocol: String = "irn",
        relayData: String? = nil,
        expiryTimestamp: UInt64? = nil,
        methods: [String]? = nil
    ) {
        self.topic = topic
        self.symKey = symKey
        self.relayProtocol = relayProtocol
        self.relayData = relayData
        self.expiryTimestamp = expiryTimestamp
        self.methods = methods
    }

    /// The link with its parameters in alphabetical order, as other implementations write it.
    public var absoluteString: String {
        var items: [(String, String)] = [("relay-protocol", relayProtocol), ("symKey", symKey)]
        if let relayData {
            items.append(("relay-data", relayData))
        }
        if let expiryTimestamp {
            items.append(("expiryTimestamp", String(expiryTimestamp)))
        }
        if let methods, !methods.isEmpty {
            items.append(("methods", methods.joined(separator: ",")))
        }
        items.sort { $0.0 < $1.0 }

        var components = URLComponents()
        components.queryItems = items.map { URLQueryItem(name: $0.0, value: $0.1) }
        return "wc:\(topic)@2?\(components.percentEncodedQuery ?? "")"
    }

    public var description: String {
        absoluteString
    }
}
