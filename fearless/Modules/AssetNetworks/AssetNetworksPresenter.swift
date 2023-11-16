import Foundation
import SoraFoundation
import SSFModels

enum AssetNetworksFilter: Int {
    case allNetworks = 0
    case myNetworks
}

final class AssetNetworksPresenter {
    // MARK: Private properties

    private weak var view: AssetNetworksViewInput?
    private let router: AssetNetworksRouterInput
    private let interactor: AssetNetworksInteractorInput
    private let wallet: MetaAccountModel
    private let viewModelFactory: AssetNetworksViewModelFactoryProtocol

    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private var chainAssets: [ChainAsset] = []
    private var prices: PriceDataUpdated = ([], false)
    private var filterValue: AssetNetworksFilter = .allNetworks
    private var sort: AssetNetworksSortType = .fiat

    // MARK: - Constructors

    init(
        interactor: AssetNetworksInteractorInput,
        router: AssetNetworksRouterInput,
        localizationManager: LocalizationManagerProtocol,
        wallet: MetaAccountModel,
        viewModelFactory: AssetNetworksViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModels = viewModelFactory.buildViewModels(
            chainAssets: chainAssets,
            accountInfos: accountInfos,
            prices: prices,
            wallet: wallet,
            locale: selectedLocale,
            filter: filterValue,
            sort: sort
        )

        view?.didReceive(viewModels: viewModels)
    }
}

// MARK: - AssetNetworksViewOutput

extension AssetNetworksPresenter: AssetNetworksViewOutput {
    func didChangeNetworkSwitcher(segmentIndex: Int) {
        guard let filterValue = AssetNetworksFilter(rawValue: segmentIndex) else {
            return
        }

        self.filterValue = filterValue
        provideViewModel()
    }

    func didLoad(view: AssetNetworksViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didSelect(chainAsset: ChainAsset) {
        router.showDetails(from: view, chainAsset: chainAsset)
    }

    func didTapSortButton() {
        let sorts = FilterSet(title: R.string.localizable.commonFilterSortHeader(preferredLanguages: selectedLocale.rLanguages), items: AssetNetworksSort.defaultFilters())
        router.showFilters(filters: [sorts], moduleOutput: self, from: view)
    }
}

// MARK: - AssetNetworksInteractorOutput

extension AssetNetworksPresenter: AssetNetworksInteractorOutput {
    func didReceiveChainAssets(_ chainAssets: [ChainAsset]) {
        self.chainAssets = chainAssets
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }
            let key = chainAsset.uniqueKey(accountId: accountId)

            let previousAccountInfo = accountInfos[key] ?? nil
            let bothNil = (previousAccountInfo == nil && accountInfo == nil)

            guard previousAccountInfo != accountInfo, !bothNil else {
                return
            }

            accountInfos[key] = accountInfo
            provideViewModel()
        case let .failure(error):
            Logger.shared.customError(error)
        }
    }

    func didReceivePricesData(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(priceDataResult):
            let priceDataUpdated = (pricesData: priceDataResult, updated: true)
            prices = priceDataUpdated
        case .failure:
            guard !prices.updated else {
                return
            }

            let priceDataUpdated = (pricesData: [], updated: true) as PriceDataUpdated
            prices = priceDataUpdated
        }

        provideViewModel()
    }
}

// MARK: - Localizable

extension AssetNetworksPresenter: Localizable {
    func applyLocalization() {}
}

extension AssetNetworksPresenter: AssetNetworksModuleInput {}

extension AssetNetworksPresenter: FiltersModuleOutput {
    func didFinishWithFilters(filters: [FilterSet]) {
        guard let sorts = filters.first?.items as? [AssetNetworksSort], let selectedSort = sorts.first(where: { $0.selected == true }) else {
            return
        }

        sort = selectedSort.type
        provideViewModel()
    }
}
