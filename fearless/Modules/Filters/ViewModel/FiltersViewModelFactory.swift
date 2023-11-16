import Foundation

protocol FiltersViewModelFactoryProtocol {
    func buildViewModel(from filters: [FilterSet], delegate: SwitchFilterTableCellViewModelDelegate?) -> FiltersViewModel
}

class FiltersViewModelFactory: FiltersViewModelFactoryProtocol {
    func buildViewModel(from filters: [FilterSet], delegate: SwitchFilterTableCellViewModelDelegate?) -> FiltersViewModel {
        let sections: [FilterSectionViewModel] = filters.compactMap { filterSet in

            let cellViewModels: [FilterCellViewModel] = filterSet.items.compactMap { baseFilterItem in
                if let switchFilterItem = baseFilterItem as? SwitchFilterItem {
                    return SwitchFilterTableCellViewModel(
                        id: switchFilterItem.id,
                        title: switchFilterItem.title,
                        enabled: switchFilterItem.selected,
                        delegate: delegate
                    )
                }

                if let filterItem = baseFilterItem as? AssetNetworksSort {
                    return SortFilterCellViewModel(
                        id: filterItem.id,
                        title: filterItem.title,
                        selected: filterItem.selected
                    )
                }

                return nil
            }

            return FilterSectionViewModel(
                title: filterSet.title,
                items: cellViewModels
            )
        }

        return FiltersViewModel(sections: sections)
    }
}
