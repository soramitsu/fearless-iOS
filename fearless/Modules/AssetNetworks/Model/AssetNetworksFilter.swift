import Foundation
import SoraFoundation

enum AssetNetworksSortType: String {
    case fiat
    case popularity
    case name

    var id: String {
        switch self {
        case .fiat:
            return "fiat"
        case .popularity:
            return "popularity"
        case .name:
            return "name"
        }
    }

    var title: String {
        switch self {
        case .fiat:
            return "Fiat Balance"
        case .popularity:
            return "Popularity"
        case .name:
            return R.string.localizable.commonName(
                preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
            )
        }
    }
}

struct AssetNetworksSort: BaseFilterItem {
    var type: AssetNetworksSortType
    var id: String
    var title: String
    var selected: Bool

    init(type: AssetNetworksSortType, selected: Bool = false) {
        self.type = type
        self.selected = selected
        id = type.id
        title = type.title
    }

    mutating func reset() {
        selected = false
    }

    mutating func changeSelectionState(isSelected: Bool) {
        selected = isSelected
    }

    static func defaultFilters() -> [AssetNetworksSort] {
        [AssetNetworksSort(type: .fiat, selected: true),
         AssetNetworksSort(type: .popularity, selected: false),
         AssetNetworksSort(type: .name, selected: false)]
    }
}
