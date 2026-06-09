/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import UIKit

public protocol Highlightable: AnyObject {
    func set(highlighted: Bool, animated: Bool)
}

extension UILabel: Highlightable {
    public func set(highlighted: Bool, animated: Bool) {
        isHighlighted = highlighted
    }
}

extension UIImageView: Highlightable {
    public func set(highlighted: Bool, animated: Bool) {
        isHighlighted = highlighted
    }
}
