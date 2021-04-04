import Foundation

struct ExtrinisicIndexWrapper: Decodable {
    let value: UInt16

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        guard let decodedIndexString = try container.decode(String.self).components(separatedBy: "-").last,
              let index = UInt16(decodedIndexString)
        else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unexpected index")
        }

        value = index
    }
}
