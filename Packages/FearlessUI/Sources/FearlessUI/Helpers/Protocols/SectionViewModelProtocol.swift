import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public struct SectionViewModel<T> {
    let title: String?
    var items: [T]
}

public extension SectionViewModel {
    var count: Int {
        return items.count
    }
}
