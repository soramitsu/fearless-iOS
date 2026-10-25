import Foundation

public struct StorageQuery: Codable {
    public let keys: [Data]
    public let blockHash: Data?

    public init(keys: [Data], blockHash: Data?) {
        self.keys = keys
        self.blockHash = blockHash
    }

    public func encode(to encoder: Encoder) throws {
        var unkeyedContainer = encoder.unkeyedContainer()

        let hexKeys = keys.map { $0.toHex(includePrefix: true) }
        try unkeyedContainer.encode(hexKeys)

        if let blockHash = blockHash {
            let hexHash = blockHash.toHex(includePrefix: true)
            try unkeyedContainer.encode(hexHash)
        }
    }
}
