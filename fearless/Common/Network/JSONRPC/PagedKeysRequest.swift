import Foundation

struct PagedKeysRequest: Encodable {
    let key: String
    let count: UInt32

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(key)
        try container.encode(count)
        /*let array: NSArray = [key, NSNumber(value: count)]
        let data = try JSONSerialization.data(withJSONObject: array)
        try container.encode(data)*/
    }
}
