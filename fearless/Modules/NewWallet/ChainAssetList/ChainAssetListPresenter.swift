import Foundation
import SoraFoundation

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
    private var chainsWithNetworkIssues: [ChainModel.Id] = []
    private var chainsWithMissingAccounts: [ChainModel.Id] = []
    private var pricesFetched = false

    private lazy var factoryOperationQueue: OperationQueue = {
        OperationQueue()
    }()

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
        let additionalDataReceived = displayType != .search && pricesFetched || displayType == .search
        guard
            let chainAssets = chainAssets,
            additionalDataReceived
        else {
            return
        }

        factoryOperationQueue.operations.forEach { $0.cancel() }
        factoryOperationQueue.cancelAllOperations()

        let operationBlock = BlockOperation()
        operationBlock.addExecutionBlock { [unowned operationBlock] in
            guard !operationBlock.isCancelled else {
                return
            }

            let viewModel = self.viewModelFactory.buildViewModel(
                wallet: self.wallet,
                chainAssets: chainAssets,
                locale: self.selectedLocale,
                accountInfos: self.lock.concurrentlyRead { [unowned self] in
                    self.accountInfos
                },
                prices: self.prices,
                chainsWithIssues: self.chainsWithNetworkIssues,
                chainsWithMissingAccounts: self.chainsWithMissingAccounts
            )

            DispatchQueue.main.async {
                self.view?.didReceive(viewModel: viewModel)
            }
        }

        factoryOperationQueue.addOperation(operationBlock)
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
            router.showChainAccount(
                from: view,
                chainAsset: viewModel.chainAsset
            )
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

    func didTapOnIssueButton(viewModel: ChainAccountBalanceCellViewModel) {
        let title = viewModel.chainAsset.chain.name + " "
            + R.string.localizable.commonNetwork(preferredLanguages: selectedLocale.rLanguages)

        var message: String = ""
        var closeActionTitle: String = ""
        if viewModel.isNetworkIssues {
            message = R.string.localizable
                .networkIssueUnavailable(preferredLanguages: selectedLocale.rLanguages)
            closeActionTitle = R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages)
        } else if viewModel.isMissingAccount {
            message = R.string.localizable
                .manageAssetsAccountMissingText(preferredLanguages: selectedLocale.rLanguages)
            closeActionTitle = R.string.localizable
                .accountsAddAccount(preferredLanguages: selectedLocale.rLanguages)
        }

        let sheetViewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeActionTitle,
            dismissCompletion: { [weak self] in
                if viewModel.isMissingAccount {
                    self?.showMissingAccountOptions(chain: viewModel.chainAsset.chain)
                }
            }
        )
        router.present(viewModel: sheetViewModel, from: view)
    }

    func didTapExpandSections(state: HiddenSectionState) {
        interactor.saveHiddenSection(state: state)
    }
}

// MARK: - ChainAssetListInteractorOutput

extension ChainAssetListPresenter: ChainAssetListInteractorOutput {
    func updateViewModel() {
        guard let chainAssets = chainAssets, chainAssets.isNotEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.view?.showEmptyState()
            }
            return
        }
        provideViewModel()
    }

    func didReceiveWallet(wallet: MetaAccountModel) {
        self.wallet = wallet
    }

    func didReceiveChainAssets(result: Result<[ChainAsset], Error>) {
        switch result {
        case let .success(chainAssets):
            self.chainAssets = chainAssets
        case let .failure(error):
            DispatchQueue.main.async {
                self.router.present(error: error, from: self.view, locale: self.selectedLocale)
            }
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):

            lock.exclusivelyWrite { [unowned self] in
                guard let accountId = self.wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                    return
                }
                let key = chainAsset.uniqueKey(accountId: accountId)
                self.accountInfos[key] = accountInfo
            }
        case let .failure(error):
            DispatchQueue.main.async {
                self.router.present(error: error, from: self.view, locale: self.selectedLocale)
            }
        }
    }

    func didReceivePricesData(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(priceDataResult):
            let priceDataUpdated = (pricesData: priceDataResult, updated: true)
            prices = priceDataUpdated
        case let .failure(error):
            let priceDataUpdated = (pricesData: [], updated: true) as PriceDataUpdated
            prices = priceDataUpdated
            router.present(error: error, from: view, locale: selectedLocale)
        }

        pricesFetched = true
        provideViewModel()
    }

    func didReceiveChainsWithIssues(_ issues: [ChainIssue]) {
        guard issues.isNotEmpty else {
            chainsWithNetworkIssues = []
            chainsWithMissingAccounts = []
            provideViewModel()
            return
        }
        issues.forEach { chainIssue in
            switch chainIssue {
            case let .network(chains):
                chainsWithNetworkIssues = chains.map { $0.chainId }
            case let .missingAccount(chains):
                chainsWithMissingAccounts = chains.map { $0.chainId }
            }
        }
        provideViewModel()
    }

    func accountInfoDeliveryDidFinish() {
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

        pricesFetched = searchIsActive
        accountInfos = [:]

        if searchIsActive {
            displayType = .search
        } else if filteredByChain {
            displayType = .chain
        } else {
            displayType = .assetChains
        }

        interactor.updateChainAssets(using: filters, sorts: sorts)
    }
}
