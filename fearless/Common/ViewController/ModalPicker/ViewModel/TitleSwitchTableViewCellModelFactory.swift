import Foundation

protocol TitleSwitchTableViewCellModelFactoryProtocol {
    func createFilters(
        options: [FilterOption],
        locale: Locale?,
        delegate: TitleSwitchTableViewCellModelDelegate?
    ) -> [TitleSwitchTableViewCellModel]
}

enum FilterOption: String, Codable {
    case hideZeroBalance
}

final class TitleSwitchTableViewCellModelFactory: TitleSwitchTableViewCellModelFactoryProtocol {
    private var enabledFilters: [FilterOption] = [.hideZeroBalance]

    func createFilters(
        options: [FilterOption],
        locale: Locale?,
        delegate: TitleSwitchTableViewCellModelDelegate?
    ) -> [TitleSwitchTableViewCellModel] {
        enabledFilters.map { option -> TitleSwitchTableViewCellModel in
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
            }
        }
    }
}
