/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public protocol CellViewModelProtocol: ViewModelProtocol {
    var cellType: UITableViewCell.Type { get }
}

public extension CellViewModelProtocol {
    var cellReusableKey: String {
        return cellType.reuseIdentifier
    }
}

