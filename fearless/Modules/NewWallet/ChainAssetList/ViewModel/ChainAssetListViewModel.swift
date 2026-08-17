import Foundation
import SoraFoundation
import SSFModels

struct ChainAssetListViewModel {
    let displayState: AssetListState
    let networkSections: [AssetNetworkSectionViewModel]
}

enum AssetNetworkSectionKind: Equatable {
    case assets
    case detected
}

struct AssetNetworkSectionViewModel: Equatable {
    let id: String
    let chainId: ChainModel.Id
    let kind: AssetNetworkSectionKind
    let networkName: String
    let ecosystemName: String
    let address: String?
    let fiatSubtotal: String?
    let syncStatus: String
    let detectedCount: Int
    let rows: [ChainAccountBalanceCellViewModel]
}

enum AssetListDisplayType {
    case chain
    case assetChains
    case search
}

enum AssetListState {
    case defaultList(cells: [ChainAccountBalanceCellViewModel], withAnimate: Bool)
    case allIsHidden
    case chainHasNetworkIssue(chain: ChainModel)
    case chainHasAccountIssue(chain: ChainModel)
    case search(cells: [ChainAccountBalanceCellViewModel])

    var rows: [ChainAccountBalanceCellViewModel] {
        switch self {
        case let .defaultList(cells, _):
            return cells
        case let .search(cells):
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
