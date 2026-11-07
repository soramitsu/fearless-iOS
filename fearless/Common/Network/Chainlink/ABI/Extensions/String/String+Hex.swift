//
//  String+Hex.swift
//  MEWwalletKit
//
//  Created by Mikhail Nikanorov on 4/25/19.
//  Copyright © 2019 MyEtherWallet Inc. All rights reserved.
//

import Foundation

private let _nonHexCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEF").inverted

extension String {
    func isHex() -> Bool {
        var rawHex = self
        rawHex.removeHexPrefix()
        rawHex = rawHex.uppercased()
        return (rawHex.rangeOfCharacter(from: _nonHexCharacterSet) == nil)
    }

    func isHexWithPrefix() -> Bool {
        guard hasHexPrefix() else { return false }
        return isHex()
    }

    mutating func removeHexPrefix() {
        if hasPrefix("0x") {
            let indexStart = index(startIndex, offsetBy: 2)
            self = String(self[indexStart...])
        }
    }

    mutating func addHexPrefix() {
        if !hasPrefix("0x") {
            self = "0x" + self
        }
    }

    mutating func alignHexBytes() {
        guard isHex(), count % 2 != 0 else {
            return
        }
        let hasPrefix = self.hasPrefix("0x")
        if hasPrefix {
            removeHexPrefix()
        }
        self = "0" + self
        if hasPrefix {
            addHexPrefix()
        }
    }

    func hasHexPrefix() -> Bool {
        hasPrefix("0x")
    }

    func stringRemoveHexPrefix() -> String {
        var string = self
        string.removeHexPrefix()
        return string
    }

    func stringAddHexPrefix() -> String {
        var string = self
        string.addHexPrefix()
        return string
    }

    func stringWithAlignedHexBytes() -> String {
        var string = self
        string.alignHexBytes()
        return string
    }
}
