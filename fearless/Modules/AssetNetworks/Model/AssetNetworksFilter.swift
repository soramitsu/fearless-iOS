import Foundation
import FearlessFoundation

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

    func title(preferredLanguages: [String]?) -> String {
        switch self {
        case .fiat:
            return "Fiat Balance"
        case .popularity:
            return "Popularity"
        case .name:
            return R.string.localizable.commonName(
                preferredLanguages: preferredLanguages
            )
        }
    }
}

struct AssetNetworksSort: BaseFilterItem {
    var type: AssetNetworksSortType
    var id: String
    var title: String
    var selected: Bool

    init(
        type: AssetNetworksSortType,
        selected: Bool = false,
        preferredLanguages: [String]? = nil
    ) {
        self.type = type
        self.selected = selected
        id = type.id
        title = type.title(preferredLanguages: preferredLanguages)
    }

    mutating func reset() {
        selected = false
    }

    mutating func changeSelectionState(isSelected: Bool) {
        selected = isSelected
    }

    static func defaultFilters(
        selected: AssetNetworksSortType,
        preferredLanguages: [String]? = nil
    ) -> [AssetNetworksSort] {
        [
            AssetNetworksSort(
                type: .fiat,
                selected: selected == .fiat,
                preferredLanguages: preferredLanguages
            ),
            AssetNetworksSort(
                type: .popularity,
                selected: selected == .popularity,
                preferredLanguages: preferredLanguages
            ),
            AssetNetworksSort(
                type: .name,
                selected: selected == .name,
                preferredLanguages: preferredLanguages
            )
        ]
    }
}
