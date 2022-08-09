typealias ChainAssetListModuleCreationResult = (view: ChainAssetListViewInput, input: ChainAssetListModuleInput)

protocol ChainAssetListViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: AssetListViewModel)
}

protocol ChainAssetListViewOutput: AnyObject {
    func didLoad(view: ChainAssetListViewInput)
}

protocol ChainAssetListInteractorInput: AnyObject {
    func setup(with output: ChainAssetListInteractorOutput)
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    )
}

protocol ChainAssetListInteractorOutput: AnyObject {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>)
    func didReceivePricesData(result: Result<[PriceData], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
}

protocol ChainAssetListRouterInput: AnyObject {}

protocol ChainAssetListModuleInput: AnyObject {
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    )
}

protocol ChainAssetListModuleOutput: AnyObject {}
