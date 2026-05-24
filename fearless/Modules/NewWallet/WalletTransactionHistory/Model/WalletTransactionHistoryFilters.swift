import Foundation
import FearlessFoundation

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

        static func type(from index: Int) -> HistoryFilterType? {
            switch index {
            case 0:
                return .transfer
            case 1:
                return .reward
            case 2:
                return .other
            default:
                return nil
            }
        }

        func title(preferredLanguages: [String]?) -> String {
            switch self {
            case .transfer:
                return R.string.localizable.transferTitle(
                    preferredLanguages: preferredLanguages
                )
            case .reward:
                return R.string.localizable.walletFiltersRewardsAndSlashes(
                    preferredLanguages: preferredLanguages
                )
            case .swap:
                return "Swap"
            case .other:
                return R.string.localizable.walletFiltersExtrinsics(
                    preferredLanguages: preferredLanguages
                )
            }
        }
    }

    var type: HistoryFilterType
    var id: String
    var title: String
    var selected: Bool

    init(
        type: HistoryFilterType,
        selected: Bool = false,
        preferredLanguages: [String]? = nil
    ) {
        self.type = type
        self.selected = selected
        id = type.id
        title = type.title(preferredLanguages: preferredLanguages)
    }

    mutating func reset() {
        selected = true
    }

    static func defaultFilters(preferredLanguages: [String]? = nil) -> [WalletTransactionHistoryFilter] {
        [WalletTransactionHistoryFilter(type: .transfer, selected: true, preferredLanguages: preferredLanguages),
         WalletTransactionHistoryFilter(type: .reward, selected: true, preferredLanguages: preferredLanguages),
         WalletTransactionHistoryFilter(type: .other, selected: true, preferredLanguages: preferredLanguages),
         WalletTransactionHistoryFilter(type: .swap, selected: true, preferredLanguages: preferredLanguages)]
    }
}
