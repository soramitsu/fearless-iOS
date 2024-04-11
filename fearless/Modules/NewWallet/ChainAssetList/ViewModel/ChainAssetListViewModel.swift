import Foundation
import SoraFoundation

struct ChainAssetListViewModel {
    let cells: [ChainAccountBalanceCellViewModel]
    let displayType: AssetListDisplayType
    let shouldRunManageAssetAnimate: Bool
    let emptyStateIsActive: Bool
}

enum AssetListDisplayType {
    case chain
    case assetChains
    case search

    var isSearch: Bool {
        switch self {
        case .chain, .assetChains:
            return false
        case .search:
            return true
        }
    }

    var emptyStateText: LocalizableResource<String> {
        LocalizableResource { locale in
            switch self {
            case .chain, .assetChains:
                return R.string.localizable.walletAllAssetsHidden(preferredLanguages: locale.rLanguages)
            case .search:
                return R.string.localizable.emptyViewTitle(preferredLanguages: locale.rLanguages)
            }
        }
    }
}
