import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

/**
 *  Protocol designed to provide arbitrary text processing interface.
 */

public protocol TextProcessing {

    /**
     *  Maps provided text to new one.
     *
     *  - paramaters:
     *      - text: String to process.
     *
     *  - returns:
     *     New text String.
     */

    func process(text: String) -> String
}

/**
 *  Implementation of TextProcessing interface designed to apply chain of processors to the text.
 */

public struct CompoundTextProcessor: TextProcessing {
    public let processors: [TextProcessing]

    public init(processors: [TextProcessing]) {
        self.processors = processors
    }

    public func process(text: String) -> String {
        processors.reduce(text) { result, processor in
            processor.process(text: result)
        }
    }
}
