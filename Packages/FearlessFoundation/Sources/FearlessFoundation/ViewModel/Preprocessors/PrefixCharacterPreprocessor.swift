import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

/**
 *  Processor that cuts prefix of the input string until reaches
 *  a character not from particular character set.
 *
 *  For example the following example outputs 'swift'
 *  ````
 *  let processor = PrefixCharacterProcessor(charset: CharacterSet(charactersIn: "-"))
 *  print(processor.process(text: "--swift"))
 *  ````
 */

public struct PrefixCharacterProcessor: TextProcessing {
    public let charset: CharacterSet

    public init(charset: CharacterSet) {
        self.charset = charset
    }

    public func process(text: String) -> String {
        let characters = text.unicodeScalars.reduce(String.UnicodeScalarView()) { result, character in
            if charset.contains(character), result.isEmpty {
                return result
            } else {
                return result + [character]
            }
        }

        return String(characters)
    }
}
