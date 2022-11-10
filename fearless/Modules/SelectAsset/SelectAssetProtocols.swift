typealias SelectAssetModuleCreationResult = (view: SelectAssetViewInput, input: SelectAssetModuleInput)

protocol SelectAssetViewInput: SelectionListViewProtocol {}

protocol SelectAssetViewOutput: SelectionListPresenterProtocol {
    func didLoad(view: SelectAssetViewInput)
}

protocol SelectAssetInteractorInput: AnyObject {
    func setup(with output: SelectAssetInteractorOutput)
}

protocol SelectAssetInteractorOutput: AnyObject {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>)
    func didReceivePricesData(result: Result<[PriceData], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
}

protocol SelectAssetRouterInput: AlertPresentable, ErrorPresentable, PresentDismissable {}

protocol SelectAssetModuleInput: AnyObject {}

protocol SelectAssetModuleOutput: AnyObject {
    func assetSelection(didCompleteWith asset: AssetModel?)
}
