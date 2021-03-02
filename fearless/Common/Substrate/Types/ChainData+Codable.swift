import Foundation
import FearlessUtils

extension ChainData: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(UInt8.self)

        if type == 0 {
            self = .none
        } else {
            guard let data = try container.decode([Data].self).first else {
                throw DecodingError.dataCorruptedError(in: container,
                                                       debugDescription: "expected array of single data item")
            }

            switch type {
            case 1:
                self = .raw(data: data)
            case 2:
                self = .blakeTwo256(data: H256(value: data))
            case 3:
                self = .sha256(data: H256(value: data))
            case 4:
                self = .keccak256(data: H256(value: data))
            case 5:
                self = .shaThree256(data: H256(value: data))
            default:
                throw DecodingError.dataCorruptedError(in: container,
                                                       debugDescription: "unexpected type found: \(type)")
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case .none:
            try container.encode(UInt8(0))
        case .raw(let data):
            try container.encode(UInt8(1))
            try container.encode([data])
        case .blakeTwo256(let hash):
            try container.encode(UInt8(2))
            try container.encode([hash.value])
        case .sha256(let hash):
            try container.encode(UInt8(3))
            try container.encode([hash.value])
        case .keccak256(let hash):
            try container.encode(UInt8(4))
            try container.encode([hash.value])
        case .shaThree256(let hash):
            try container.encode(UInt8(5))
            try container.encode([hash.value])
        }
    }
}
