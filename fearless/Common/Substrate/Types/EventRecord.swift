import Foundation
import FearlessUtils

struct EventRecord: Decodable {
    let phase: Phase
    let event: Event

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        phase = try container.decode(Phase.self)
        event = try container.decode(Event.self)
    }
}

extension EventRecord {
    var extrinsicIndex: UInt32? {
        if case let .applyExtrinsic(index) = phase {
            return index
        } else {
            return nil
        }
    }
}

enum Phase: Decodable {
    static let extrinsicField = "ApplyExtrinsic"
    static let finalizationField = "Finalization"
    static let initializationField = "Initialization"

    case applyExtrinsic(index: UInt32)
    case finalization
    case initialization

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case Phase.extrinsicField:
            let index = try container.decode(StringScaleMapper<UInt32>.self).value
            self = .applyExtrinsic(index: index)
        case Phase.finalizationField:
            self = .finalization
        case Phase.initializationField:
            self = .initialization
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected phase"
            )
        }
    }
}

struct Event: Decodable {
    let moduleIndex: UInt8
    let eventIndex: UInt32
    let params: JSON

    init(from decoder: Decoder) throws {
        var unkeyedContainer = try decoder.unkeyedContainer()

        moduleIndex = try unkeyedContainer.decode(UInt8.self)
        eventIndex = try unkeyedContainer.decode(UInt32.self)
        params = try unkeyedContainer.decode(JSON.self)
    }
}

private extension Optional {
    func unwrap(throwing error: Error) throws -> Wrapped {
        guard let value = self else { throw error }
        return value
    }
}

enum ExtrinsicStatus: Decodable {
    static let readyField = "ready"
    static let broadcastField = "broadcast"
    static let inBlockField = "inBlock"
    static let finalizedField = "finalized"

    case ready
    case broadcast([String])
    case inBlock(String)
    case finalized(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decoded = try container.decode(JSON.self)

        let decodingError = DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unexpected extrinsic state"
        )

        let type = try (decoded.dictValue?.keys.first ?? decoded.stringValue).unwrap(throwing: decodingError)
        let value = try decoded[type].unwrap(throwing: decodingError)

        switch type {
        case ExtrinsicStatus.readyField:
            self = .ready
        case ExtrinsicStatus.broadcastField:
            self = .broadcast(
                try value.arrayValue
                    .unwrap(throwing: decodingError)
                    .map { try $0.stringValue.unwrap(throwing: decodingError) }
            )
        case ExtrinsicStatus.inBlockField:
            self = .inBlock(try value.stringValue.unwrap(throwing: decodingError))
        case ExtrinsicStatus.finalizedField:
            self = .finalized(try value.stringValue.unwrap(throwing: decodingError))
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected extrinsic state"
            )
        }
    }
}
