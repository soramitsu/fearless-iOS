import UIKit

final class FiltersInteractor {
    weak var presenter: FiltersInteractorOutputProtocol?

    private var filterItems: [BaseFilterItem]

    init(filterItems: [BaseFilterItem]) {
        self.filterItems = filterItems
    }
}

extension FiltersInteractor: FiltersInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(filterItems: filterItems)
    }

    func resetFilters() {
        filterItems.forEach { $0.reset() }
    }

    func applyFilters() {
        presenter?.didFinishWithFilters(filters: filterItems)
    }
}
