import Foundation
import SSFModels

protocol TitleSwitchTableViewCellModelFactoryProtocol {
    func createFilters(
        options: [FilterOption],
        locale: Locale?,
        delegate: TitleSwitchTableViewCellModelDelegate?
    ) -> [TitleSwitchTableViewCellModel]

    func createSortings(
        options: [PoolSortOption],
        selectedOption: PoolSortOption,
        locale: Locale?
    ) -> [SortPickerTableViewCellModel]
}

// enum FilterOption: String, Codable {
//    case hideZeroBalance
//    case hiddenSectionOpen
// }

enum PoolSortOption: Equatable {
    case totalStake(assetSymbol: String)
    case numberOfMembers
}

final class TitleSwitchTableViewCellModelFactory: TitleSwitchTableViewCellModelFactoryProtocol {
    private var enabledFilters: [FilterOption] = [.hideZeroBalance]

    func createFilters(
        options: [FilterOption],
        locale: Locale?,
        delegate: TitleSwitchTableViewCellModelDelegate?
    ) -> [TitleSwitchTableViewCellModel] {
        enabledFilters.compactMap { option -> TitleSwitchTableViewCellModel? in
            switch option {
            case .hideZeroBalance:
                let model = TitleSwitchTableViewCellModel(
                    icon: R.image.zeroBalanceIcon(),
                    title: R.string.localizable.chainSelectionHideZeroBalances(preferredLanguages: locale?.rLanguages),
                    switchIsOn: options.contains(option),
                    filterOption: option
                )
                model.delegate = delegate
                return model
            case .hiddenSectionOpen:
                return nil
            }
        }
    }

    func createSortings(
        options: [PoolSortOption],
        selectedOption: PoolSortOption,
        locale: Locale?
    ) -> [SortPickerTableViewCellModel] {
        options.compactMap { option in
            switch option {
            case .numberOfMembers:
                let model = SortPickerTableViewCellModel(
                    title: R.string.localizable.stakingPoolSortPoolMembers(preferredLanguages: locale?.rLanguages),
                    switchIsOn: selectedOption == option,
                    sortOption: option
                )
                return model

            case let .totalStake(assetSymbol):
                let model = SortPickerTableViewCellModel(
                    title: R.string.localizable.stakingValidatorTotalStakeToken(assetSymbol, preferredLanguages: locale?.rLanguages),
                    switchIsOn: selectedOption == option,
                    sortOption: option
                )
                return model
            }
        }
    }
}
