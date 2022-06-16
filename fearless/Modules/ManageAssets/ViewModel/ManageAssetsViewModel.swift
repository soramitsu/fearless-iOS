import Foundation

struct ManageAssetsTableSection {
    let cellModels: [ManageAssetsTableViewCellModel]
}

struct SelectedChainModel {
    let chainId: ChainModel.Id?
    let title: String
    let icon: ImageViewModelProtocol?
}

enum ManageAssetsViewState {
    case loading
    case loaded(viewModel: ManageAssetsViewModel)
}

struct ManageAssetsViewModel {
    let sections: [ManageAssetsTableSection]
    let applyEnabled: Bool
    let selectedChain: SelectedChainModel
}
