import Foundation

public enum HexCodingStrategy {
    static func encoding(data: Data, encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
//        let hex = data.toHex(includePrefix: true)
//        try container.encode(hex)
        let array = data.map { String($0) }
        try container.encode(array)
    }

    static func decoding(with decoder: Decoder) throws -> Data {
        let container = try decoder.singleValueContainer()
//        let hex = try container.decode(String.self)
//        return try Data(hexStringSSF: hex)
        let bytes = try container.decode([String].self).map { byteRaw -> UInt8 in
            guard let byte = UInt8(byteRaw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: container.codingPath, debugDescription: "")
                )
            }

            return byte
        }

        return Data(bytes)
    }
}

public extension JSONEncoder {
    static func scaleCompatible() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dataEncodingStrategy = .custom(HexCodingStrategy.encoding(data:encoder:))
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

public extension JSONDecoder {
    static func scaleCompatible(snakeCase: Bool = true) -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = .custom(HexCodingStrategy.decoding(with:))

        if snakeCase {
            decoder.keyDecodingStrategy = .convertFromSnakeCase
        }
        return decoder
    }
}

struct EncodingContainer<T: Encodable>: Encodable {
    let value: T
}

struct DecodingContainer<T: Decodable>: Decodable {
    let value: T
}

struct JsonContainer: Codable {
    let value: JSON
}

public extension Encodable {
    func toScaleCompatibleJSON() throws -> JSON {
        let container = EncodingContainer(value: self)

        let data = try JSONEncoder.scaleCompatible().encode(container)
        let json = try JSONDecoder.scaleCompatible(snakeCase: false).decode(
            JsonContainer.self,
            from: data
        ).value

        return json
    }
}

public extension JSON {
    func map<T: Decodable>(to _: T.Type) throws -> T {
        let encoder = JSONEncoder.scaleCompatible()
        let encodingContainer = JsonContainer(value: self)
        let data = try encoder.encode(encodingContainer)

        let decoder = JSONDecoder.scaleCompatible()
        return try decoder.decode(DecodingContainer<T>.self, from: data).value
    }

    func plainMap<T: Decodable>(to _: T.Type) throws -> T {
        let encoder = JSONEncoder.scaleCompatible()
        let encodingContainer = JsonContainer(value: self)
        let data = try encoder.encode(encodingContainer)

        let decoder = JSONDecoder.scaleCompatible(snakeCase: false)
        return try decoder.decode(DecodingContainer<T>.self, from: data).value
    }
}

public extension DynamicScaleEncoding {
    func append<T: Encodable>(_ codable: T, ofType type: String) throws {
        let json = try codable.toScaleCompatibleJSON()
        try append(json: json, type: type)
    }
}

public extension DynamicScaleDecoding {
    func read<T: Decodable>(of type: String) throws -> T {
        let json = try read(type: type)
        return try json.map(to: T.self)
    }
}
