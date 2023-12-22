import Foundation

class NftFiltersViewModelFactory: FiltersViewModelFactoryProtocol {
    func buildViewModel(from filters: [FilterSet], delegate: SwitchFilterTableCellViewModelDelegate?, mode _: FiltersMode) -> FiltersViewModel {
        let sections: [FilterSectionViewModel] = filters.compactMap { filterSet in

            let cellViewModels: [SwitchFilterTableCellViewModel] = filterSet.items.compactMap { baseFilterItem in
                if let switchFilterItem = baseFilterItem as? SwitchFilterItem {
                    return SwitchFilterTableCellViewModel(
                        id: switchFilterItem.id,
                        title: switchFilterItem.title,
                        enabled: switchFilterItem.selected,
                        delegate: delegate
                    )
                }

                return nil
            }

            return FilterSectionViewModel(
                title: filterSet.title,
                items: cellViewModels
            )
        }

        return FiltersViewModel(sections: sections, mode: .multiSelection)
    }
}
