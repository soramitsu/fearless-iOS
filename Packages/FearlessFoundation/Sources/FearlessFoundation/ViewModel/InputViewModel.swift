import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

/**
 *  Protocol is designed to provide data and accept input from input fields.
 */

public protocol InputViewModelProtocol {
    /**
     *  Title to display for input field
     */
    var title: String { get }

    /**
     *  Placeholder or hint to display for input field
     */

    var placeholder: String { get }

    /**
     *  Handler to process input from input field
     */

    var inputHandler: InputHandling { get }

    /**
     *  Capitalization rule to apply to input field
     */

    var autocapitalization: UITextAutocapitalizationType { get }
}

/**
 *  Concreate implementation of InputViewModelProtocol
 */

public struct InputViewModel: InputViewModelProtocol {
    public let title: String
    public let placeholder: String
    public let inputHandler: InputHandling
    public let autocapitalization: UITextAutocapitalizationType

    /**
     *  - parameters:
     *      - inputHandler: Handler to process input text.
     *      - title: Title to display in input field. By default **empty string**.
     *      - placeholder: Placeholder or hint to display in input field. By default **input field**.
     *      - autocapitalization: Capitalization rule to apply to input field. By default **.sentences**.
     */

    public init(inputHandler: InputHandling,
                title: String = "",
                placeholder: String = "",
                autocapitalization: UITextAutocapitalizationType = .sentences) {
        self.title = title
        self.placeholder = placeholder
        self.inputHandler = inputHandler
        self.autocapitalization = autocapitalization
    }
}
