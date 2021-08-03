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
