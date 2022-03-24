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
    func saveAssetsOrder(assets: [AssetModel])
    func switchAssetEnabledState(_ asset: AssetModel)
}

protocol ManageAssetsInteractorOutputProtocol: AnyObject {
    func didReceiveChains(result: Result<[ChainModel], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainId: ChainModel.Id)
    func didReceiveSortOrder(sortedKeys: [String]?)
}

protocol ManageAssetsWireframeProtocol: AlertPresentable, ErrorPresentable, PresentDismissable {}
