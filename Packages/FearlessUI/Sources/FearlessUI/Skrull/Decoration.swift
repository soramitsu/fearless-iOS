/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public struct Decoration {
    var position: CGPoint
    var size: CGSize
    var cornerRadii: CGSize?
    var cornerRoundingMode: UIRectCorner?
    var fillColor: UIColor?
    var strokeColor: UIColor?
    var strokeWidth: CGFloat?
    var shadowColor: UIColor?
    var shadowOffset: CGSize?
    var shadowRadius: CGFloat?

    var shouldFill: Bool {
        return fillColor != nil
    }

    var shouldStroke: Bool {
        return strokeColor != nil
    }
}
