//
//  Data+Length.swift
//  MEWwalletKit
//
//  Created by Mikhail Nikanorov on 4/29/19.
//  Copyright © 2019 MyEtherWallet Inc. All rights reserved.
//

import Foundation

extension Data {
    mutating func setLength(_ length: Int, appendFromLeft: Bool = true, negative: Bool = false) {
        guard count < length else {
            return
        }

        let leftLength = length - count

        if appendFromLeft {
            self = Data(repeating: negative ? 0xFF : 0x00, count: leftLength) + self
        } else {
            self += Data(repeating: negative ? 0xFF : 0x00, count: leftLength)
        }
    }

    func setLengthLeft(_ toBytes: Int, isNegative: Bool = false) -> Data {
        var data = self
        data.setLength(toBytes, negative: isNegative)
        return data
    }

    func setLengthRight(_ toBytes: Int, isNegative: Bool = false) -> Data {
        var data = self
        data.setLength(toBytes, appendFromLeft: false, negative: isNegative)

        return data
    }
}
