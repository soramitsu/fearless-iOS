import UIKit
/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: GPL-3.0
 */

import Foundation

public extension CGPoint {
    static var skrullTopLeft: CGPoint {
        return CGPoint(x: 0.0, y: 0.0)
    }

    static var skrullTopRight: CGPoint {
        return CGPoint(x: 1.0, y: 0.0)
    }

    static var skrullBottomLeft: CGPoint {
        return CGPoint(x: 0.0, y: 1.0)
    }

    static var skrullBottomRight: CGPoint {
        return CGPoint(x: 1.0, y: 1.0)
    }

    static var skrullCenter: CGPoint {
        return CGPoint(x: 0.5, y: 0.5)
    }
}
