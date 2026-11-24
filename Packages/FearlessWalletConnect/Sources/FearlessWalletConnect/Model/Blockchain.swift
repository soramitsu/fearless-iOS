import Foundation

enum CAIP {
    static func isNamespace(_ value: Substring) -> Bool {
        (3 ... 8).contains(value.count) && value.utf8.allSatisfy { byte in
            (0x61 ... 0x7A).contains(byte) || (0x30 ... 0x39).contains(byte) || byte == 0x2D
        }
    }

    static func isReference(_ value: Substring) -> Bool {
        (1 ... 64).contains(value.count) && value.utf8.allSatisfy { byte in
            (0x61 ... 0x7A).contains(byte) || (0x41 ... 0x5A).contains(byte) || (0x30 ... 0x39).contains(byte)
                || byte == 0x2D || byte == 0x5F
        }
    }

    static func isAddress(_ value: Substring) -> Bool {
        (1 ... 128).contains(value.count) && value.utf8.allSatisfy { byte in
            (0x61 ... 0x7A).contains(byte) || (0x41 ... 0x5A).contains(byte) || (0x30 ... 0x39).contains(byte)
                || byte == 0x2D || byte == 0x2E || byte == 0x25
        }
    }

    /// A namespace key is a namespace (`eip155`) or one chain of it (`eip155:1`).
    static func isNamespaceKey(_ value: String) -> Bool {
        isNamespace(Substring(value)) || Blockchain(value) != nil
    }
}

/// A CAIP-2 chain id, `namespace:reference`, for example `eip155:1`.
public struct Blockchain: Hashable, Sendable, CustomStringConvertible, LosslessStringConvertible {
    public let namespace: String
    public let reference: String

    public init?(_ string: String) {
        let parts = string.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, CAIP.isNamespace(parts[0]), CAIP.isReference(parts[1]) else {
            return nil
        }
        namespace = String(parts[0])
        reference = String(parts[1])
    }

    public init?(namespace: String, reference: String) {
        self.init("\(namespace):\(reference)")
    }

    public var absoluteString: String {
        "\(namespace):\(reference)"
    }

    public var description: String {
        absoluteString
    }
}

extension Blockchain: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let blockchain = Blockchain(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a CAIP-2 chain id")
        }
        self = blockchain
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(absoluteString)
    }
}

/// A CAIP-10 account id, `namespace:reference:address`.
public struct Account: Hashable, Sendable, CustomStringConvertible, LosslessStringConvertible {
    public let blockchain: Blockchain
    public let address: String

    public init?(_ string: String) {
        let parts = string.split(separator: ":", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            let blockchain = Blockchain(namespace: String(parts[0]), reference: String(parts[1])),
            CAIP.isAddress(parts[2])
        else {
            return nil
        }
        self.blockchain = blockchain
        address = String(parts[2])
    }

    public init?(blockchain: Blockchain, address: String) {
        guard CAIP.isAddress(Substring(address)) else {
            return nil
        }
        self.blockchain = blockchain
        self.address = address
    }

    public init?(chainIdentifier: String, address: String) {
        guard let blockchain = Blockchain(chainIdentifier) else {
            return nil
        }
        self.init(blockchain: blockchain, address: address)
    }

    public var namespace: String {
        blockchain.namespace
    }

    public var reference: String {
        blockchain.reference
    }

    public var absoluteString: String {
        "\(blockchain.absoluteString):\(address)"
    }

    public var description: String {
        absoluteString
    }
}

extension Account: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let account = Account(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a CAIP-10 account id")
        }
        self = account
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(absoluteString)
    }
}
