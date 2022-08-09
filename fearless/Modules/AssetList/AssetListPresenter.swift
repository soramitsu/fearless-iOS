final class AssetListPresenter {
    private let interactor: AssetListInteractorInput
    private let selectedMetaAccount: MetaAccountModel
    private var chainAssets: [ChainAsset]?

    init(
        interactor: AssetListInteractorInput,
        selectedMetaAccount: MetaAccountModel
    ) {
        self.interactor = interactor
        self.selectedMetaAccount = selectedMetaAccount
    }
}

private extension AssetListPresenter {
    func provideViewModel() {
        
    }
}

extension AssetListPresenter: AssetListModuleInput {
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    ) {
        interactor.updateChainAssets(using: filters, sorts: sorts)
    }
}

extension AssetListPresenter: AssetListInteractorOutput {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>) {
        switch result {
        case let .success(chainAssets):
            self.chainAssets = chainAssets
            provideViewModel()
        case let .failure(error):
//            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }
    
    func didReceivePricesData(result: Result<[PriceData], Error>) {
        <#code#>
    }
    
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        <#code#>
    }
}
