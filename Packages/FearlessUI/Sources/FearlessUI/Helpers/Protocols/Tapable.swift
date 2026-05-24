import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public typealias TapableClosure = () -> Void

public protocol TapableProtocol {
    var action: TapableClosure? { get }
}
