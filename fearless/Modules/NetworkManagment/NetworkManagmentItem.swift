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
