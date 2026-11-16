import Foundation
import SoraFoundation
import SSFModels

struct ChainAssetListViewModel {
    let displayState: AssetListState
    let networkSections: [AssetNetworkSectionViewModel]
    var walletId: String?
    var lens: PortfolioLens = .token
    /// The wallet home's search field and network chips. The search screen has its own field and shows neither.
    var showsDiscovery = false
    /// The one-list search field's text, as the list was built with it.
    var searchText: String = ""
    /// All networks, the networks the wallet holds something on (largest first), and a chosen Popular or Favorites.
    var networkChips: [PortfolioNetworkChip] = []
    /// A search found nothing on the chosen networks: offer to search all of them.
    var canSearchAllNetworks = false
    /// A search found nothing at all.
    var searchFoundNothing = false
    var tokenRows: [TokenGroupRowViewModel] = []
    var zeroTokenRows: [TokenGroupRowViewModel] = []
    var tokenChildCells: [AssetKey: ChainAccountBalanceCellViewModel] = [:]
    var usesCustomOrder = false
    var isWalletEmpty = false
    var showsFundingCard = false
    var canReceive = false
    var canBuy = false
    /// What the header total leaves out, labelled under the list.
    var exclusions: [PortfolioExclusionCaption] = []
    /// Above the list until answered: assets hidden in the previous version now hold funds.
    var hiddenFundsNotice: PortfolioHiddenFundsNotice?
}

/// A network filter chip. Its identity is the wallet's network filter identifier, the one the header's network
/// button sets ("all", "popular", "favourite" or a chain id).
struct PortfolioNetworkChip: Equatable {
    let id: String
    let title: String
    let selected: Bool
}

struct TokenGroupRowViewModel: Equatable {
    let model: TokenGroupRowModel
    let amountText: String
    let fiatText: String?
}

/// "N hidden assets hold funds" with Review and Keep hidden (portfolio contract §5).
struct PortfolioHiddenFundsNotice: Equatable {
    let assetKeys: [AssetKey]
    let title: String
    let message: String
}

struct PortfolioExclusionCaption: Equatable {
    enum Kind: Equatable {
        /// "N hidden assets not included · Manage": opens Manage assets.
        case hiddenAssets
        /// "N testnet assets not included · Manage": opens Manage assets, where a testnet
        /// can be shown; its value is never counted.
        case testnetAssets
        case unpricedAssets
        case poolStakes
    }

    let kind: Kind
    let text: String
}

enum AssetNetworkSectionKind: Equatable {
    case assets
    case detected
    case zeroNetworks(count: Int)
}

struct AssetNetworkSectionViewModel: Equatable {
    let id: String
    let chainId: ChainModel.Id
    let kind: AssetNetworkSectionKind
    let networkName: String
    let ecosystemName: String
    let address: String?
    let fiatSubtotal: String?
    let syncStatus: String?
    let detectedCount: Int
    let rows: [ChainAccountBalanceCellViewModel]
    var parentSectionId: String?
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
