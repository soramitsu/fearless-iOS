protocol AssetListModuleInput: AnyObject {
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    )
}

protocol AssetListInteractorInput: AnyObject {
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    )
}

protocol AssetListInteractorOutput: AnyObject {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>)
    func didReceivePricesData(result: Result<[PriceData], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
}
