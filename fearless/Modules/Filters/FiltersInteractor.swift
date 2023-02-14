import UIKit

final class FiltersInteractor {
    weak var presenter: FiltersInteractorOutputProtocol?

    private var filters: [FilterSet]

    init(filters: [FilterSet]) {
        self.filters = filters
    }
}

extension FiltersInteractor: FiltersInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(filters: filters)
    }

    func resetFilters() {
        for filterIndex in 0 ..< filters.count {
            for itemIndex in 0 ..< filters[filterIndex].items.count {
                filters[filterIndex].items[itemIndex].reset()
            }
        }

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
