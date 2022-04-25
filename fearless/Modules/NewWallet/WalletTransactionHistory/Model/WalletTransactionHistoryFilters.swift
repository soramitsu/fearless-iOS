import Foundation
import SoraFoundation

class WalletTransactionHistoryFilter: SwitchFilterItem {
    enum HistoryFilterType: String {
        case transfer
        case reward
        case other

        var id: String {
            switch self {
            case .transfer:
                return "transfer"
            case .reward:
                return "reward"
            case .other:
                return "extrinsic"
            }
        }

        var title: String {
            switch self {
            case .transfer:
                return R.string.localizable.transferTitle(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
            case .reward:
                return R.string.localizable.walletFiltersRewardsAndSlashes(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
            case .other:
                return R.string.localizable.walletFiltersExtrinsics(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
            }
        }
    }

    var type: HistoryFilterType

    init(type: HistoryFilterType, selected: Bool = false) {
        self.type = type

        super.init(id: type.id, title: type.title, selected: selected)
    }

    static func defaultFilters() -> [WalletTransactionHistoryFilter] {
        [WalletTransactionHistoryFilter(type: .transfer, selected: true),
         WalletTransactionHistoryFilter(type: .reward, selected: true),
         WalletTransactionHistoryFilter(type: .other, selected: true)]
    }
}
