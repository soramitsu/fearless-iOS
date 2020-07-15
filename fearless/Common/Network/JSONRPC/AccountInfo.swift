import Foundation
import BigInt

struct AccountInfo: ScaleDecodable {
    let nonce: UInt32
    let refcount: UInt8
    let data: AccountData

    init(scaleDecoder: ScaleDecoding) throws {
        nonce = try UInt32(scaleDecoder: scaleDecoder)
        refcount = try UInt8(scaleDecoder: scaleDecoder)
        data = try AccountData(scaleDecoder: scaleDecoder)
    }
}

struct AccountData: ScaleDecodable {
    let free: Balance
    let reserved: Balance
    let miscFrozen: Balance
    let feeFrozen: Balance

    init(scaleDecoder: ScaleDecoding) throws {
        free = try Balance(scaleDecoder: scaleDecoder)
        reserved = try Balance(scaleDecoder: scaleDecoder)
        miscFrozen = try Balance(scaleDecoder: scaleDecoder)
        feeFrozen = try Balance(scaleDecoder: scaleDecoder)
    }
}

struct Balance: ScaleDecodable {
    let value: BigUInt

    init(scaleDecoder: ScaleDecoding) throws {
        let data = try scaleDecoder.read(count: 16)
        value = BigUInt(Data(data.reversed()))
        try scaleDecoder.confirm(count: 16)
    }
}
