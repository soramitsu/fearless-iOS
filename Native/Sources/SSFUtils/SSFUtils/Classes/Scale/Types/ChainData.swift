import Foundation

public enum ChainDataError: Error {
    case undefined(index: UInt8)
}

public enum ChainData: ScaleCodable {
    case none
    case raw(data: Data)
    case blakeTwo256(data: H256)
    case sha256(data: H256)
    case keccak256(data: H256)
    case shaThree256(data: H256)

    public init(scaleDecoder: ScaleDecoding) throws {
        let firstByte = try UInt8(scaleDecoder: scaleDecoder)

        if firstByte == 0 {
            self = .none
        } else if firstByte >= 1 && firstByte <= 33 {
            let data = try scaleDecoder.readAndConfirm(count: Int(firstByte) - 1)
            self = .raw(data: data)
        } else {
            switch firstByte - 34 {
            case 0:
                let data = try H256(scaleDecoder: scaleDecoder)
                self = .blakeTwo256(data: data)
            case 1:
                let data = try H256(scaleDecoder: scaleDecoder)
                self = .sha256(data: data)
            case 2:
                let data = try H256(scaleDecoder: scaleDecoder)
                self = .keccak256(data: data)
            case 3:
                let data = try H256(scaleDecoder: scaleDecoder)
                self = .shaThree256(data: data)
            default:
                throw ChainDataError.undefined(index: firstByte)
            }
        }
    }

    public func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case .none:
            try UInt8(0).encode(scaleEncoder: scaleEncoder)
        case let .raw(data):
            let length = min(data.count, 32)
            try UInt8(length + 1).encode(scaleEncoder: scaleEncoder)
            scaleEncoder.appendRaw(data: data[0 ..< length])
        case let .blakeTwo256(data):
            try UInt8(34).encode(scaleEncoder: scaleEncoder)
            try data.encode(scaleEncoder: scaleEncoder)
        case let .sha256(data):
            try UInt8(35).encode(scaleEncoder: scaleEncoder)
            try data.encode(scaleEncoder: scaleEncoder)
        case let .keccak256(data):
            try UInt8(36).encode(scaleEncoder: scaleEncoder)
            try data.encode(scaleEncoder: scaleEncoder)
        case let .shaThree256(data):
            try UInt8(37).encode(scaleEncoder: scaleEncoder)
            try data.encode(scaleEncoder: scaleEncoder)
        }
    }
}

extension ChainData: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .none:
            hasher.combine(0)
        case let .raw(data):
            hasher.combine(1)
            hasher.combine(data)
        case let .blakeTwo256(data):
            hasher.combine(2)
            hasher.combine(data.value)
        case let .sha256(data):
            hasher.combine(3)
            hasher.combine(data.value)
        case let .keccak256(data):
            hasher.combine(4)
            hasher.combine(data.value)
        case let .shaThree256(data):
            hasher.combine(5)
            hasher.combine(data.value)
        }
    }
}
