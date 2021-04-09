import Foundation
import FearlessUtils
import BigInt

struct AccountInfo: ScaleDecodable {
    let nonce: UInt32
    let consumers: UInt32
    let providers: UInt32
    let sufficients: UInt32
    let data: AccountData

    init(v28: AccountInfoV28) {
        self.nonce = v28.nonce
        self.consumers = v28.consumers
        self.providers = v28.providers
        self.sufficients = 0
        self.data = v28.data
    }

    init(scaleDecoder: ScaleDecoding) throws {
        nonce = try UInt32(scaleDecoder: scaleDecoder)
        consumers = try UInt32(scaleDecoder: scaleDecoder)
        providers = try UInt32(scaleDecoder: scaleDecoder)
        sufficients = try UInt32(scaleDecoder: scaleDecoder)
        data = try AccountData(scaleDecoder: scaleDecoder)
    }
}

struct AccountInfoV28: ScaleDecodable {
    let nonce: UInt32
    let consumers: UInt32
    let providers: UInt32
    let data: AccountData

    init(scaleDecoder: ScaleDecoding) throws {
        nonce = try UInt32(scaleDecoder: scaleDecoder)
        consumers = try UInt32(scaleDecoder: scaleDecoder)
        providers = try UInt32(scaleDecoder: scaleDecoder)
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
