import Foundation

struct ManageAssetsTableSection {
    let cellModels: [ManageAssetsTableViewCellModel]
}

enum ManageAssetsViewState {
    case loading
    case loaded(viewModel: ManageAssetsViewModel)
}

struct ManageAssetsViewModel {
    let sections: [ManageAssetsTableSection]
    let applyEnabled: Bool
}
