/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public protocol AdaptiveDesignable {
    var baseDesignSize: CGSize { get }
    var designScaleRatio: CGSize { get }
    var isAdaptiveHeightDecreased: Bool { get }
    var isAdaptiveHeightIncreased: Bool { get }
    var isAdaptiveWidthDecreased: Bool { get }
    var isAdaptiveWidthIncreased: Bool { get }
}

extension AdaptiveDesignable {
    public var baseDesignSize: CGSize {
        return CGSize(width: 375, height: 667)
    }

    public var designScaleRatio: CGSize {
        let screenBounds = UIScreen.main.bounds
        return CGSize(width: screenBounds.width / baseDesignSize.width,
                      height: screenBounds.height / baseDesignSize.height)
    }

    public var isAdaptiveHeightDecreased: Bool {
        return designScaleRatio.height < 1.0
    }

    public var isAdaptiveHeightIncreased: Bool {
        return designScaleRatio.height > 1.0
    }

    public var isAdaptiveWidthDecreased: Bool {
        return designScaleRatio.width < 1.0
    }

    public var isAdaptiveWidthIncreased: Bool {
        return designScaleRatio.width > 1.0
    }
}
