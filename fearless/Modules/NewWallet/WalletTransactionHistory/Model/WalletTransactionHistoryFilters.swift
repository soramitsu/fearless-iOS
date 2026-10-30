import Foundation
import SoraFoundation

struct WalletTransactionHistoryFilter: SwitchFilterItem {
    enum HistoryFilterType: String {
        case transfer
        case reward
        case swap
        case other

        var id: String {
            switch self {
            case .transfer:
                return "transfer"
            case .reward:
                return "reward"
            case .swap:
                return "swap"
            case .other:
                return "extrinsic"
            }
        }

        var title: String {
            switch self {
            case .transfer:
                return R.string.localizable.transferTitle(
                    preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
                )
            case .reward:
                return R.string.localizable.walletFiltersRewardsAndSlashes(
                    preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
                )
            case .swap:
                return "Swap"
            case .other:
                return R.string.localizable.walletFiltersExtrinsics(
                    preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
                )
            }
        }
    }

    var type: HistoryFilterType
    var id: String
    var title: String
    var selected: Bool

    init(type: HistoryFilterType, selected: Bool = false) {
        self.type = type
        self.selected = selected
        id = type.id
        title = type.title
    }

    mutating func reset() {
        selected = true
    }

    static func defaultFilters() -> [WalletTransactionHistoryFilter] {
        [WalletTransactionHistoryFilter(type: .transfer, selected: true),
         WalletTransactionHistoryFilter(type: .reward, selected: true),
         WalletTransactionHistoryFilter(type: .other, selected: true),
         WalletTransactionHistoryFilter(type: .swap, selected: true)]
    }
}
