import Foundation
import SoraFoundation
import SSFModels

protocol TableSection {
    associatedtype T
    var cells: [T] { get }
}

struct ChainAssetListViewModel {
    let displayState: AssetListState
}

enum AssetListDisplayType {
    case chain
    case assetChains
    case search
}

struct ChainAssetListSection: TableSection {
    typealias T = ChainAccountBalanceCellViewModel
    let cells: [ChainAccountBalanceCellViewModel]
}

struct SCardListSection: TableSection {
    typealias T = SCardListViewModel
    let cells: [SCardListViewModel]
}

enum AssetListState {
    case defaultList(sections: [any TableSection], withAnimate: Bool)
    case allIsHidden
    case chainHasNetworkIssue(chain: ChainModel)
    case chainHasAccountIssue(chain: ChainModel)
    case search(sections: [any TableSection])
    
    func sections() -> [any TableSection] {
        switch self {
        case .defaultList(let sections, _), .search(let sections):
            return sections
        default:
            return []
        }
    }
    
    var isEmpty: Bool {
        switch self {
        case .defaultList(let sections, _), .search(let sections):
            return sections.map { $0.cells }.reduce([], +).first == nil
        default:
            return true
        }
    }

    var isSearch: Bool {
        switch self {
        case .search: return true
        default: return false
        }
    }
}
