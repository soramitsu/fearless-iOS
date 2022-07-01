import Foundation

private struct OptionalDecodable<T: Decodable>: Decodable {
    let base: T?

    init(from decoder: Decoder) throws {
        let decoder = try decoder.singleValueContainer()
        base = try? decoder.decode(T.self)
    }
}

extension KeyedDecodingContainer {
    func decodeOptionalArray<T: Decodable>(_: [T].Type, forKey key: K) -> [T] {
        (try? decode([OptionalDecodable<T>]?.self, forKey: key))
            .orEmpty()
            .compactMap(\.base)
    }
}

extension JSONDecoder {
    func decodeOptionalArray<T: Decodable>(_: [T].Type, from data: Data) -> [T] {
        (try? JSONDecoder().decode([OptionalDecodable<T>]?.self, from: data))
            .orEmpty()
            .compactMap(\.base)
    }
}
