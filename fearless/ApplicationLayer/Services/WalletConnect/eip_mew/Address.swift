//
//  Address.swift
//  MEWwalletKit
//
//  Created by Mikhail Nikanorov on 4/25/19.
//  Copyright © 2019 MyEtherWallet Inc. All rights reserved.
//

import Foundation
import CryptoSwift

public struct Address: CustomDebugStringConvertible {
    public enum Ethereum {
        static let length = 42
    }

    private var _address: String
    public var address: String {
        _address
    }

    public var data: Data {
        Data(hex: address)
    }

    public init?(data: Data, prefix: String? = nil) {
        self.init(address: data.toHexString(), prefix: prefix)
    }

    public init(raw: String) {
        _address = raw
    }

    public init?(address: String, prefix: String? = nil) {
        var address = address
        if let prefix = prefix, !address.hasPrefix(prefix) {
            address.insert(contentsOf: prefix, at: address.startIndex)
        }
        if address.stringAddHexPrefix().count == Address.Ethereum.length, prefix == nil, address.isHex(), let eip55address = address.stringAddHexPrefix().eip55() {
            _address = eip55address
        } else {
            _address = address
        }
    }

    public init?(ethereumAddress: String) {
        let value = ethereumAddress.stringAddHexPrefix()
        guard value.count == Address.Ethereum.length, value.isHex(), let address = value.eip55() else { return nil } // 42 = 0x + 20bytes
        _address = address
    }

    public var debugDescription: String {
        _address
    }
}

extension Address: Equatable {
    public static func == (lhs: Address, rhs: Address) -> Bool {
        lhs._address.lowercased() == rhs._address.lowercased()
    }
}
