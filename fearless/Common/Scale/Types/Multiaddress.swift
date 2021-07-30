import Foundation
import FearlessUtils
import BigInt

enum MultiaddressError: Error {
    case invalidType
}

enum Multiaddress: ScaleCodable {
    case accountId(_ value: Data)
    case index(_ value: BigUInt)
    case raw(_ value: Data)
    case address32(_ value: Data)
    case address20(_ value: Data)

    init(scaleDecoder: ScaleDecoding) throws {
        let caseValue = try scaleDecoder.readAndConfirm(count: 1)

        switch caseValue[0] {
        case 0:
            let accountId = try scaleDecoder
                .readAndConfirm(count: Int(ExtrinsicConstants.accountIdLength))
            self = .accountId(accountId)
        case 1:
            let index = try BigUInt(scaleDecoder: scaleDecoder)
            self = .index(index)
        case 2:
            let bytes = try [UInt8](scaleDecoder: scaleDecoder)
            self = .raw(Data(bytes))
        case 3:
            let address = try scaleDecoder.readAndConfirm(count: 32)
            self = .address32(address)
        case 4:
            let address = try scaleDecoder.readAndConfirm(count: 20)
            self = .address20(address)
        default:
            throw MultiaddressError.invalidType
        }
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case let .accountId(value):
            scaleEncoder.appendRaw(data: Data([0]) + value)
        case let .index(index):
            scaleEncoder.appendRaw(data: Data([1]))
            try index.encode(scaleEncoder: scaleEncoder)
        case let .raw(value):
            scaleEncoder.appendRaw(data: Data([2]))
            let bytes = value.map { $0 }
            try bytes.encode(scaleEncoder: scaleEncoder)
        case let .address32(address):
            scaleEncoder.appendRaw(data: Data([3]) + address)
        case let .address20(address):
            scaleEncoder.appendRaw(data: Data([4]) + address)
        }
    }
}

extension Multiaddress {
    var accountId: Data? {
        if case let .accountId(value) = self {
            return value
        } else {
            return nil
        }
    }
}
