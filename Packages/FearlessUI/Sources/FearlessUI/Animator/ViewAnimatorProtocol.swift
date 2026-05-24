/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public protocol ViewAnimatorProtocol {
    var duration: TimeInterval { get }

    func animate(view: UIView, completionBlock: ((Bool) -> Void)?)
}
