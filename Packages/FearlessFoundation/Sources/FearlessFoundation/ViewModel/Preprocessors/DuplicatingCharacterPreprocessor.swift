import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

/**
 *  Processor that leave only single character from sequence of the same characters
 *
 *  For example the following example outputs 'swift-alive'
 *
 *  ````
 *  let processor = DuplicatingCharacterProcessor(charset: CharacterSet(charactersIn: "-"))
 *  print(processor.process(text: "swift---alive"))
 *  ````
 */

public struct DuplicatingCharacterProcessor: TextProcessing {
    public let charset: CharacterSet

    public init(charset: CharacterSet) {
        self.charset = charset
    }

    public func process(text: String) -> String {
        let characters = text.unicodeScalars.reduce(String.UnicodeScalarView()) { result, character in
            if charset.contains(character), result.last == character {
                return result
            } else {
                return result + [character]
            }
        }

        return String(characters)
    }
}
