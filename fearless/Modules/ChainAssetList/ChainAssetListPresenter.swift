import Foundation
import SoraFoundation

final class ChainAssetListPresenter {
    // MARK: Private properties

    private weak var view: ChainAssetListViewInput?
    private let router: ChainAssetListRouterInput
    private let interactor: ChainAssetListInteractorInput

    private let viewModelFactory: ChainAssetListViewModelFactoryProtocol
    private let wallet: MetaAccountModel
    private var chainAssets: [ChainAsset]?

    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private var prices: PriceDataUpdated = ([], false)

    // MARK: - Constructors

    init(
        interactor: ChainAssetListInteractorInput,
        router: ChainAssetListRouterInput,
        localizationManager: LocalizationManagerProtocol,
        wallet: MetaAccountModel,
        viewModelFactory: ChainAssetListViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        guard let chainAssets = chainAssets else {
            return
        }

        let viewModel = viewModelFactory.buildViewModel(
            selectedMetaAccount: wallet,
            chainAssets: chainAssets,
            locale: selectedLocale,
            accountInfos: accountInfos,
            prices: prices
        )

        view?.didReceive(viewModel: viewModel)
        print("viewModelviewModel", viewModel.sections.count)
    }
}

// MARK: - ChainAssetListViewOutput

extension ChainAssetListPresenter: ChainAssetListViewOutput {
    func didLoad(view: ChainAssetListViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel) {
        if viewModel.chainAsset.chain.isSupported {
            router.showChainAccount(from: view, chainAsset: viewModel.chainAsset)
        } else {
            router.presentWarningAlert(
                from: view,
                config: WarningAlertConfig.unsupportedChainConfig(with: selectedLocale)
            ) { [weak self] in
                self?.router.showAppstoreUpdatePage()
            }
        }
    }
}

// MARK: - ChainAssetListInteractorOutput

extension ChainAssetListPresenter: ChainAssetListInteractorOutput {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>) {
        switch result {
        case let .success(chainAssets):
            self.chainAssets = chainAssets
            provideViewModel()
        case let .failure(error):
            router.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }
            let key = chainAsset.uniqueKey(accountId: accountId)
            accountInfos[key] = accountInfo
        case let .failure(error):
            router.present(error: error, from: view, locale: selectedLocale)
        }
        provideViewModel()
    }

    func didReceivePricesData(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(priceDataResult):
            let priceDataUpdated = (pricesData: priceDataResult, updated: true)
            prices = priceDataUpdated
        case let .failure(error):
            router.present(error: error, from: view, locale: selectedLocale)
        }

        provideViewModel()
    }
}

// MARK: - Localizable

extension ChainAssetListPresenter: Localizable {
    func applyLocalization() {}
}

extension ChainAssetListPresenter: ChainAssetListModuleInput {
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    ) {
        interactor.updateChainAssets(using: filters, sorts: sorts)
    }
}
