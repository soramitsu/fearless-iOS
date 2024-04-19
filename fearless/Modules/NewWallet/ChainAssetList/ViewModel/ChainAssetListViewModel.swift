import Foundation
import SoraFoundation

struct ChainAssetListViewModel {
    let displayState: AssetListState
}

enum AssetListDisplayType {
    case chain
    case assetChains
    case search
}

enum AssetListState {
    case defaultList(cells: [ChainAccountBalanceCellViewModel], withAnimate: Bool)
    case allIsHidden
    case chainHasNetworkIssue
    case chainHasAccountIssue
    case search

    var rows: [ChainAccountBalanceCellViewModel] {
        switch self {
        case let .defaultList(cells, _):
            return cells
        default:
            return []
        }
    }

    var isSearch: Bool {
        switch self {
        case .search: return true
        default: return false
        }
    }
}
