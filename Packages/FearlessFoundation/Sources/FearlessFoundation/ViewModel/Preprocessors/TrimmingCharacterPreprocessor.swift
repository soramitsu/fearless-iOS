import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

/**
 *  Processor that trims provided text.
 *
 *  For example the following example outputs 'swift'
 *  ````
 *  let processor = TrimmingCharacterProcessor(charset: CharacterSet(charactersIn: "-"))
 *  print(processor.process(text: "--swift--"))
 *  ````
 */

public struct TrimmingCharacterProcessor: TextProcessing {
    public let charset: CharacterSet

    public init(charset: CharacterSet) {
        self.charset = charset
    }

    public func process(text: String) -> String {
        return text.trimmingCharacters(in: charset)
    }
}
