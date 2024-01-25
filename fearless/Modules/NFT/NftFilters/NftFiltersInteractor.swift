import UIKit

final class NftFiltersInteractor {
    weak var presenter: NftFiltersInteractorOutputProtocol?

    private var filters: [FilterSet]

    init(filters: [FilterSet]) {
        self.filters = filters
    }
}

extension NftFiltersInteractor: NftFiltersInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(filters: filters)
    }

    func applyFilters() {
        presenter?.didFinishWithFilters(filters: filters)
    }

    func switchFilterState(id: String, selected: Bool, completion: (Bool) -> Void) {
        for index in 0 ..< filters.count {
            if let itemIndex = filters[index].items.firstIndex(where: { $0.id == id }) {
                if var switchFilter = filters[index].items[itemIndex] as? SwitchFilterItem {
                    switchFilter.selected = selected
                    filters[index].items[itemIndex] = switchFilter
                }
            }
        }

        var selectedFilters: [SwitchFilterItem] = []
        filters.forEach { filterSet in
            filterSet.items.forEach { item in
                if let switchItem = item as? SwitchFilterItem, switchItem.selected {
                    selectedFilters.append(switchItem)
                }
            }
        }
        completion(selectedFilters.isNotEmpty)
    }
}
