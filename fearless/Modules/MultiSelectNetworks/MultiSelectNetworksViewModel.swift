import Foundation

struct MultiSelectNetworksViewModel {
    let selectedCountTitle: String
    let cells: [CellModel]
    let allIsSelected: Bool

    struct CellModel: Hashable {
        let chainId: String
        let chainName: String
        let icon: RemoteImageViewModel?
        let isSelected: Bool

        func toggle() -> Self {
            CellModel(
                chainId: chainId,
                chainName: chainName,
                icon: icon,
                isSelected: !isSelected
            )
        }
    }

    func replace(cells: [CellModel]) -> Self {
        MultiSelectNetworksViewModel(
            selectedCountTitle: selectedCountTitle,
            cells: cells,
            allIsSelected: allIsSelected
        )
    }
}
