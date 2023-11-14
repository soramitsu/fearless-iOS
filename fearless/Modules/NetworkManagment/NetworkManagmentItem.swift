//
//  NetworkManagmentItem.swift
//  fearless
//
//  Created by Soramitsu on 08.11.2023.
//  Copyright © 2023 Soramitsu. All rights reserved.
//

import Foundation
import SSFModels

enum NetworkManagmentItem {
    case allItem
    case popular
    case favourite
    case chain(ChainModel)

    var chain: ChainModel? {
        switch self {
        case .allItem, .popular, .favourite:
            return nil
        case let .chain(chain):
            return chain
        }
    }
}
