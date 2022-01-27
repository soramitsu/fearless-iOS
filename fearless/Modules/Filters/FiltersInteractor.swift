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
        filters.map(\.items).reduce([], +).forEach { $0.reset() }

        presenter?.didReceive(filters: filters)
    }

    func applyFilters() {
        presenter?.didFinishWithFilters(filters: filters)
    }

    func switchFilterState(id: String, selected: Bool) {
        if let switchFilter = filters.map(\.items).reduce([], +).first(where: { $0.id == id }) as? SwitchFilterItem {
            switchFilter.selected = selected
        }
    }
}
