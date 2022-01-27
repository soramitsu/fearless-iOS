import Foundation

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
                return "Transfers"
            case .reward:
                return "Rewards"
            case .other:
                return "Other transactions"
            }
        }
    }

    var type: HistoryFilterType

    init(type: HistoryFilterType, selected: Bool = false) {
        self.type = type

        super.init(id: type.id, title: type.title, selected: selected)
    }
}
