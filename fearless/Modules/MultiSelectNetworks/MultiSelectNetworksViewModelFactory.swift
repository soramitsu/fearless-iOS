import Foundation
import SSFModels

protocol MultiSelectNetworksViewModelFactory {
    func buildViewModel(
        dataSource: [ChainModel],
        selectedChains: [ChainModel.Id]?,
        searchText: String?
    ) -> MultiSelectNetworksViewModel
}

final class MultiSelectNetworksViewModelFactoryImpl: MultiSelectNetworksViewModelFactory {
    func buildViewModel(
        dataSource: [ChainModel],
        selectedChains: [ChainModel.Id]?,
        searchText: String?
    ) -> MultiSelectNetworksViewModel {
        var filtredDataSource = dataSource
        if let searchText = searchText {
            filtredDataSource = dataSource.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }

        let cells = filtredDataSource.map {
            MultiSelectNetworksViewModel.CellModel(
                chainId: $0.chainId,
                chainName: $0.name,
                icon: RemoteImageViewModel(url: $0.icon),
                isSelected: selectedChains?.contains($0.chainId) == true
            )
        }
        let selectedCountTitle = "Selected: \(cells.filter { $0.isSelected }.count)"
        let allIsSelected = filtredDataSource.compactMap {
            selectedChains?.contains($0.chainId)
        }.filter { $0 == true }
        return MultiSelectNetworksViewModel(
            selectedCountTitle: selectedCountTitle,
            cells: cells,
            allIsSelected: filtredDataSource.count == allIsSelected.count
        )
    }
}
