import Foundation

enum ManageAssetsViewState {
    case loading
    case loaded(viewModel: ManageAssetsViewModel)
}

struct ManageAssetsViewModel {
    let cellModels: [ManageAssetsTableViewCellModel]
}
