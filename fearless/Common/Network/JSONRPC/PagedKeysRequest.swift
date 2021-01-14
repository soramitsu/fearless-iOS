import Foundation

struct PagedKeysRequest: Encodable {
    let key: String
    let count: UInt32
    let offset: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(key)
        try container.encode(count)

        if let offset = offset {
            try container.encode(offset)
        }
    }
}
