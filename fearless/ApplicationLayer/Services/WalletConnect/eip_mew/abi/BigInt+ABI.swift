//
//  BigInt+ABI.swift
//  MEWwalletKit
//
//  Created by Nail Galiaskarov on 3/18/21.
//  Copyright © 2021 MyEtherWallet Inc. All rights reserved.
//

import Foundation
import BigInt

extension BigInt {
    func toTwosComplement() -> Data {
        if sign == BigInt.Sign.plus {
            return magnitude.serialize()
        } else {
            let serializedLength = magnitude.serialize().count
            let MAX = BigUInt(1) << (serializedLength * 8)
            let twoComplement = MAX - magnitude
            return twoComplement.serialize()
        }
    }
}

extension BigUInt {
    func abiEncode(bits: UInt64) -> Data? {
        let data = serialize()
        let paddedLength = Int(ceil(Double(bits) / 8.0))
        let padded = data.setLengthLeft(paddedLength)
        return padded
    }
}

extension BigInt {
    func abiEncode(bits: UInt64) -> Data? {
        let isNegative = self < BigInt(0)
        let data = toTwosComplement()
        let paddedLength = Int(ceil(Double(bits) / 8.0))
        let padded = data.setLengthLeft(paddedLength, isNegative: isNegative)
        return padded
    }
}

extension BigInt {
    static func fromTwosComplement(data: Data) -> BigInt {
        let isPositive = ((data[0] & 128) >> 7) == 0
        if isPositive {
            let magnitude = BigUInt(data)
            return BigInt(magnitude)
        } else {
            let MAX = (BigUInt(1) << (data.count * 8))
            let magnitude = MAX - BigUInt(data)
            let bigint = BigInt(0) - BigInt(magnitude)
            return bigint
        }
    }
}
