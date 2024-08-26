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
    private var filterValue: AssetNetworksFilter = .allNetworks
    private var sort: AssetNetworksSortType = .fiat
    private var chainsWithIssue: [ChainIssue] = []
    private var chainSettings: [ChainSettings] = []

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
            wallet: wallet,
            locale: selectedLocale,
            filter: filterValue,
            sort: sort,
            chainsWithIssue: chainsWithIssue,
            chainSettings: chainSettings
        )

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceive(viewModels: viewModels)
        }
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
        let sorts = FilterSet(
            title: nil,
            items: AssetNetworksSort.defaultFilters(selected: sort)
        )
        let title = R.string.localizable.commonFilterSortHeader(preferredLanguages: selectedLocale.rLanguages)
        router.showFilters(title: title, filters: [sorts], moduleOutput: self, from: view)
    }

    func didTapResolveIssue(for chainAsset: ChainAsset) {
        let issues: [ChainIssue] = chainsWithIssue.compactMap {
            switch $0 {
            case let .network(chains):
                let chain = chains.filter { $0.chainId == chainAsset.chain.chainId }
                return .network(chains: chain)
            case let .missingAccount(chains):
                let chain = chains.filter { $0.chainId == chainAsset.chain.chainId }
                return .missingAccount(chains: chain)
            }
        }
        router.showIssueNotification(
            from: view,
            issues: issues,
            wallet: wallet
        )
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

    func didReceive(chainSettings: [ChainSettings]) {
        self.chainSettings = chainSettings
        provideViewModel()
    }

    func didReceiveChainsWithIssues(_ issues: [ChainIssue]) {
        chainsWithIssue = issues
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
