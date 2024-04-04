import Foundation
import SoraFoundation

struct ChainAssetListViewModel {
    let cells: [ChainAccountBalanceCellViewModel]
    let emptyState: ChainAssetListViewModelEmptyState?
    let isSearch: Bool
    let shouldRunManageAssetAnimate: Bool

    var emptyStateIsActive: Bool {
        emptyState != nil
    }
}

enum ChainAssetListViewModelEmptyState {
    case search
    case hidden

    var text: LocalizableResource<String> {
        LocalizableResource { locale in
            switch self {
            case .search:
                return R.string.localizable.emptyViewTitle(preferredLanguages: locale.rLanguages)
            case .hidden:
                return R.string.localizable.walletAllAssetsHidden(preferredLanguages: locale.rLanguages)
            }
        }
    }
}
