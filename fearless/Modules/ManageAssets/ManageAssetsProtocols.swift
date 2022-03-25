import Foundation

protocol ManageAssetsViewProtocol: ControllerBackedProtocol {
    func didReceive(state: ManageAssetsViewState)
    func didReceive(locale: Locale)
}

protocol ManageAssetsPresenterProtocol: AnyObject {
    func setup()
    func move(viewModel: ManageAssetsTableViewCellModel, from: Int, to: Int)
    func didTapCloseButton()
}

protocol ManageAssetsInteractorInputProtocol: AnyObject {
    func setup()
    func saveAssetsOrder(assets: [ChainAsset])
    func saveAssetIdsEnabled(_ assetIdsEnabled: [String])
}

protocol ManageAssetsInteractorOutputProtocol: AnyObject {
    func didReceiveChains(result: Result<[ChainModel], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainId: ChainModel.Id)
    func didReceiveSortOrder(_ sortedKeys: [String]?)
    func didReceiveAssetIdsEnabled(_ assetIdsEnabled: [String]?)
}

protocol ManageAssetsWireframeProtocol: AlertPresentable, ErrorPresentable, PresentDismissable {}
