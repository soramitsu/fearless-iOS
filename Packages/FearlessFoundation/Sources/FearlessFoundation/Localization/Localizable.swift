import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol Localizable: AnyObject {
    var localizationManager: LocalizationManagerProtocol? { get set }

    func applyLocalization()
}

private struct LocalizableConstants {
    static var localizationManagerKey: UInt8 = 0
}

public extension Localizable {
    var localizationManager: LocalizationManagerProtocol? {
        set {

            let currentManager = localizationManager

            guard newValue !== currentManager else {
                return
            }

            currentManager?.removeObserver(by: self)

            newValue?.addObserver(with: self) { [weak self] (_, _) in
                self?.applyLocalization()
            }

            objc_setAssociatedObject(self,
                                     &LocalizableConstants.localizationManagerKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)

            applyLocalization()
        }

        get {
            return objc_getAssociatedObject(self, &LocalizableConstants.localizationManagerKey)
                as? LocalizationManagerProtocol
        }
    }
}
