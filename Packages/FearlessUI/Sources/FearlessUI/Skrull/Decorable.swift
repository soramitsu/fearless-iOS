import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol Decorable {
    var decorations: [Decoration] { get }
}
