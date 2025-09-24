import Foundation
import SSFModels

protocol TitleSwitchTableViewCellModelFactoryProtocol {
    func createSortings(
        options: [PoolSortOption],
        selectedOption: PoolSortOption,
        locale: Locale?
    ) -> [SortPickerTableViewCellModel]
}

enum PoolSortOption: Equatable {
    case totalStake(assetSymbol: String)
    case numberOfMembers
}

final class TitleSwitchTableViewCellModelFactory: TitleSwitchTableViewCellModelFactoryProtocol {
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
