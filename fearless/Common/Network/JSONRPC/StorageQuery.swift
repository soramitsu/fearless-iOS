import Foundation

struct StorageQuery: Encodable {
    let keys: [Data]
    let blockHash: Data?

    func encode(to encoder: Encoder) throws {
        var unkeyedContainer = encoder.unkeyedContainer()

        let hexKeys = keys.map { $0.toHex(includePrefix: true) }
        try unkeyedContainer.encode(hexKeys)

        if let blockHash = blockHash {
            let hexHash = blockHash.toHex(includePrefix: true)
            try unkeyedContainer.encode(hexHash)
        }
    }
}
