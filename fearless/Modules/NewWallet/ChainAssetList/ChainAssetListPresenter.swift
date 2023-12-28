import Foundation
import SoraFoundation
import SSFModels

enum AssetListDisplayType {
    case chain
    case assetChains
    case search
}

typealias PriceDataUpdated = (pricesData: [PriceData], updated: Bool)

final class ChainAssetListPresenter {
    // MARK: Private properties

    private let lock = ReaderWriterLock()

    private weak var view: ChainAssetListViewInput?
    private let router: ChainAssetListRouterInput
    private let interactor: ChainAssetListInteractorInput

    private let viewModelFactory: ChainAssetListViewModelFactoryProtocol
    private var wallet: MetaAccountModel
    private var chainAssets: [ChainAsset]?

    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private var prices: PriceDataUpdated = ([], false)
    private var displayType: AssetListDisplayType = .assetChains
    private var chainsWithMissingAccounts: [ChainModel.Id] = []

    private var activeFilters: [ChainAssetsFetching.Filter] = []

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
        guard let chainAssets = self.chainAssets else {
            return
        }

        lock.concurrentlyRead {
            let accountInfosCopy = self.accountInfos
            let prices = self.prices
            let chainsWithMissingAccounts = self.chainsWithMissingAccounts

            let viewModel = self.viewModelFactory.buildViewModel(
                wallet: self.wallet,
                chainAssets: chainAssets,
                locale: self.selectedLocale,
                accountInfos: accountInfosCopy,
                prices: prices,
                chainsWithMissingAccounts: chainsWithMissingAccounts,
                activeFilters: self.activeFilters
            )

            DispatchQueue.main.async {
                self.view?.didReceive(viewModel: viewModel)
            }
        }
    }

    private func showMissingAccountOptions(chain: ChainModel) {
        let unused = (wallet.unusedChainIds ?? []).contains(chain.chainId)
        let options: [MissingAccountOption?] = [.create, .import, unused ? nil : .skip]
        let uniqueChainModel = UniqueChainModel(
            meta: wallet,
            chain: chain
        )

        let actions: [SheetAlertPresentableAction] = options.compactMap { option in
            switch option {
            case .create:
                let title = R.string.localizable
                    .createNewAccount(preferredLanguages: selectedLocale.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.router.showCreate(uniqueChainModel: uniqueChainModel, from: self?.view)
                }
            case .import:
                let title = R.string.localizable
                    .alreadyHaveAccount(preferredLanguages: selectedLocale.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.router.showImport(uniqueChainModel: uniqueChainModel, from: self?.view)
                }
            case .skip:
                let title = R.string.localizable
                    .missingAccountSkip(preferredLanguages: selectedLocale.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.interactor.markUnused(chain: uniqueChainModel.chain)
                }
            case .none:
                return nil
            }
        }

        router.presentAccountOptions(
            from: view,
            locale: selectedLocale,
            actions: actions
        )
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
            interactor.getAvailableChainAssets(chainAsset: viewModel.chainAsset) { [weak self] availableChainAssets in
                guard let strongSelf = self else { return }
                DispatchQueue.main.async {
                    if availableChainAssets.count > 1, strongSelf.displayType != .chain {
                        strongSelf.router.showAssetNetworks(
                            from: strongSelf.view,
                            chainAsset: viewModel.chainAsset
                        )
                    } else {
                        strongSelf.router.showChainAccount(
                            from: strongSelf.view,
                            chainAsset: viewModel.chainAsset
                        )
                    }
                }
            }
        } else {
            router.presentWarningAlert(
                from: view,
                config: WarningAlertConfig.unsupportedChainConfig(with: selectedLocale)
            ) { [weak self] in
                self?.router.showAppstoreUpdatePage()
            }
        }
    }

    func didTapAction(actionType: SwipableCellButtonType, viewModel: ChainAccountBalanceCellViewModel) {
        switch actionType {
        case .send:
            router.showSendFlow(
                from: view,
                chainAsset: viewModel.chainAsset,
                wallet: wallet
            )
        case .receive:
            router.showReceiveFlow(
                from: view,
                chainAsset: viewModel.chainAsset,
                wallet: wallet
            )
        case .teleport:
            break
        case .hide:
            interactor.hideChainAsset(viewModel.chainAsset)
        case .show:
            interactor.showChainAsset(viewModel.chainAsset)
        }
    }

    func didTapExpandSections(state: HiddenSectionState) {
        interactor.saveHiddenSection(state: state)
    }

    func didPullToRefresh() {
        interactor.reload(fetchPrices: prices.updated)
    }
}

// MARK: - ChainAssetListInteractorOutput

extension ChainAssetListPresenter: ChainAssetListInteractorOutput {
    func updateViewModel(isInitSearchState _: Bool) {
        provideViewModel()
    }

    func didReceiveWallet(wallet: MetaAccountModel) {
        self.wallet = wallet
    }

    func handleWalletChanged(wallet: MetaAccountModel) {
        lock.exclusivelyWrite { [weak self] in
            self?.accountInfos = [:]
        }
        self.wallet = wallet
    }

    func didReceiveChainAssets(result: Result<[ChainAsset], Error>) {
        switch result {
        case let .success(chainAssets):
            lock.exclusivelyWrite { [weak self] in
                guard let self = self else { return }
                self.chainAssets = chainAssets
            }
            provideViewModel()
        case let .failure(error):
            Logger.shared.customError(error)
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }
            let key = chainAsset.uniqueKey(accountId: accountId)

            let previousAccountInfo = lock.concurrentlyRead {
                accountInfos[key] ?? nil
            }
            let bothNil = (previousAccountInfo == nil && accountInfo == nil)

            guard previousAccountInfo != accountInfo, !bothNil else {
                return
            }

            lock.exclusivelyWrite { [weak self] in
                guard let self = self else { return }

                self.accountInfos[key] = accountInfo
            }
            provideViewModel()

        case let .failure(error):
            Logger.shared.customError(error)
        }
    }

    func didReceivePricesData(result: Result<[PriceData], Error>) {
        lock.exclusivelyWrite { [weak self] in
            guard let self = self else { return }
            switch result {
            case let .success(priceDataResult):
                let priceDataUpdated = (pricesData: priceDataResult, updated: true)
                self.prices = priceDataUpdated
            case .failure:
                guard !self.prices.updated else {
                    return
                }

                let priceDataUpdated = (pricesData: [], updated: true) as PriceDataUpdated
                self.prices = priceDataUpdated
            }
        }
        provideViewModel()
    }

    func didReceiveChainsWithIssues(_ issues: [ChainIssue]) {
        guard issues.isNotEmpty else {
            chainsWithMissingAccounts = []
            provideViewModel()
            return
        }
        lock.exclusivelyWrite { [weak self] in
            guard let self = self else { return }
            issues.forEach { chainIssue in
                if case let .missingAccount(chains) = chainIssue {
                    self.chainsWithMissingAccounts = chains.map { $0.chainId }
                }
            }
        }
        provideViewModel()
    }

    func didReceive(accountInfosByChainAssets: [ChainAsset: AccountInfo?]) {
        let balances = accountInfosByChainAssets.reduce(into: [ChainAssetKey: AccountInfo?]()) { newDict, initialDict in
            let chainAsset = initialDict.key
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }

            let key = chainAsset.uniqueKey(accountId: accountId)
            newDict[key] = initialDict.value
        }

        lock.exclusivelyWrite { [weak self] in
            guard let self = self else { return }
            self.accountInfos = balances.merging(self.accountInfos, uniquingKeysWith: { old, _ in
                old
            })
        }
        provideViewModel()
    }
}

// MARK: - Localizable

extension ChainAssetListPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension ChainAssetListPresenter: ChainAssetListModuleInput {
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor]
    ) {
        activeFilters = filters

        let filteredByChain = filters.contains(where: { filter in
            if case ChainAssetsFetching.Filter.chainId = filter {
                return true
            }

            return false
        })

        let searchIsActive = filters.contains(where: { filter in
            if case ChainAssetsFetching.Filter.search = filter {
                return true
            }

            return false
        })

        accountInfos = [:]

        if searchIsActive {
            displayType = .search
        } else if filteredByChain {
            displayType = .chain
        } else {
            displayType = .assetChains
        }

        interactor.updateChainAssets(using: filters, sorts: sorts, useCashe: true)
    }
}

// MARK: - BannersModuleOutput?

extension ChainAssetListPresenter: BannersModuleOutput {
    func reloadBannersView() {
        DispatchQueue.main.async {
            self.view?.reloadBanners()
        }
    }
}
