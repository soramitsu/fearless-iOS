import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public extension CGSize {
    func skrullMapX(_ pointX: CGFloat) -> CGFloat {
        return pointX / width
    }

    func skrullMapY(_ pointY: CGFloat) -> CGFloat {
        return pointY / height
    }

    func skrullMap(point: CGPoint) -> CGPoint {
        return CGPoint(x: skrullMapX(point.x), y: skrullMapY(point.y))
    }
}
