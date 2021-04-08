import Foundation
import SoraFoundation

enum WalletHistoryFilterRow: Int, CaseIterable {
    case transfers
    case rewardsAndSlashes
    case extrinsics

    var title: LocalizableResource<String> {
        switch self {
        case .transfers:
            return LocalizableResource { locale in
                R.string.localizable.walletFiltersTransfers(preferredLanguages: locale.rLanguages)
            }
        case .rewardsAndSlashes:
            return LocalizableResource { locale in
                R.string.localizable
                    .walletFiltersRewardsAndSlashes(preferredLanguages: locale.rLanguages)
            }
        case .extrinsics:
            return LocalizableResource { locale in
                R.string.localizable.walletFiltersExtrinsics(preferredLanguages: locale.rLanguages)
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
