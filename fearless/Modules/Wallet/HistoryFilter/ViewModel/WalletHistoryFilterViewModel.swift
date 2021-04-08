import Foundation
import SoraFoundation

enum WalletHistoryFilterRow: Int, CaseIterable {
    case transfers
    case rewardsAndSlashes
    case extrinsics

    var title: LocalizableResource<String> {
        switch self {
        case .transfers:
            return LocalizableResource { _ in
                "Transfers"
            }
        case .rewardsAndSlashes:
            return LocalizableResource { _ in
                "Reward"
            }
        case .extrinsics:
            return LocalizableResource { _ in
                "Other transactions"
            }
        }
    }

    var filter: WalletHistoryFilter {
        switch self {
        case .transfers:
            return .transfers
        case .rewardsAndSlashes:
            return .rewardsAndSlashes
        case .extrinsics:
            return .extrinsics
        }
    }
}

struct WalletHistoryFilterItemViewModel {
    let title: LocalizableResource<String>
    let isOn: Bool
}

struct WalletHistoryFilterViewModel {
    let items: [WalletHistoryFilterItemViewModel]
    let canApply: Bool
    let canReset: Bool
}
