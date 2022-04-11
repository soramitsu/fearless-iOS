import Foundation

protocol ManageAssetsViewProtocol: ControllerBackedProtocol {
    func didReceive(state: ManageAssetsViewState)
    func didReceive(locale: Locale)
}

protocol ManageAssetsPresenterProtocol: AnyObject {
    func setup()
    func move(viewModel: ManageAssetsTableViewCellModel, from: IndexPath, to: IndexPath)
    func didTapCloseButton()
    func didTapApplyButton()
    func searchBarTextDidChange(_ text: String)
}

protocol ManageAssetsInteractorInputProtocol: AnyObject {
    func setup()
    func saveAssetsOrder(assets: [ChainAsset])
    func saveAssetIdsEnabled(_ assetIdsEnabled: [String])
    func markUnused(chain: ChainModel)
    func saveAllChanges()
}

protocol ManageAssetsInteractorOutputProtocol: AnyObject {
    func didReceiveChains(result: Result<[ChainModel], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainId: ChainModel.Id)
    func didReceiveSortOrder(_ sortedKeys: [String]?)
    func didReceiveAssetIdsEnabled(_ assetIdsEnabled: [String]?)
    func saveDidComplete()
}

protocol ManageAssetsWireframeProtocol: AlertPresentable, ErrorPresentable, PresentDismissable {
    func presentAccountOptions(
        from view: ControllerBackedProtocol?,
        locale: Locale?,
        options: [MissingAccountOption],
        uniqueChainModel: UniqueChainModel,
        skipBlock: @escaping (ChainModel) -> Void
    )

    func showImport(
        uniqueChainModel: UniqueChainModel,
        from view: ControllerBackedProtocol?
    )
}
