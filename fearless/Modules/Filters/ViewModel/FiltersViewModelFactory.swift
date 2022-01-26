import Foundation

protocol FiltersViewModelFactoryProtocol {
    func buildViewModel(from items: [BaseFilterItem]) -> FiltersViewModel
}

class FiltersViewModelFactory: FiltersViewModelFactoryProtocol {
    func buildViewModel(from items: [BaseFilterItem]) -> FiltersViewModel {
        let viewModels: [SwitchFilterTableCellViewModel] = items.compactMap { baseFilterItem in
            if let switchFilterItem = baseFilterItem as? SwitchFilterItem {
                return SwitchFilterTableCellViewModel(
                    id: switchFilterItem.id,
                    title: switchFilterItem.title,
                    enabled: switchFilterItem.selected
                )
            }

            return nil
        }

        return FiltersViewModel(cellModels: viewModels)
    }
}
