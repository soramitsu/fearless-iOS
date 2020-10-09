import Foundation
import FearlessUtils
import BigInt

struct AccountInfo: ScaleDecodable {
    let nonce: UInt32
    let refcount: UInt32
    let data: AccountData

    init(scaleDecoder: ScaleDecoding) throws {
        nonce = try UInt32(scaleDecoder: scaleDecoder)
        refcount = try UInt32(scaleDecoder: scaleDecoder)
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

struct Balance: ScaleCodable {
    let value: BigUInt

    init(value: BigUInt) {
        self.value = value
    }

    init(scaleDecoder: ScaleDecoding) throws {
        let data = try scaleDecoder.read(count: 16)
        value = BigUInt(Data(data.reversed()))
        try scaleDecoder.confirm(count: 16)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        var encodedData: [UInt8] = value.serialize().reversed()

        while encodedData.count < 16 {
            encodedData.append(0)
        }

        scaleEncoder.appendRaw(data: Data(encodedData))
    }
}
