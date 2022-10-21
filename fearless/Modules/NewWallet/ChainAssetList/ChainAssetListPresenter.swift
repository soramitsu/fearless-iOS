import Foundation
import SoraFoundation

enum AssetListDisplayType {
    case chain
    case assetChains
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
    private var accountInfosFetched = false
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
        guard
            let chainAssets = chainAssets,
            accountInfosFetched,
            pricesFetched
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
                displayType: self.displayType,
                selectedMetaAccount: self.wallet,
                chainAssets: chainAssets,
                locale: self.selectedLocale,
                accountInfos: self.lock.concurrentlyRead { [unowned self] in
                    self.accountInfos
                },
                prices: self.prices,
                chainsWithIssues: self.chainsWithNetworkIssues
            )

            DispatchQueue.main.async {
                self.view?.didReceive(viewModel: viewModel)
            }
        }

        factoryOperationQueue.addOperation(operationBlock)
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
                wallet: wallet,
                transferFinishBlock: nil
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
        let closeAction = SheetAlertPresentableAction(
            title: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            style: UIFactory.default.createMainActionButton(),
            handler: nil
        )
        let title = viewModel.chainAsset.chain.name + " "
            + R.string.localizable.commonNetwork(preferredLanguages: selectedLocale.rLanguages)
        let subtitle = R.string.localizable.networkIssueUnavailable(preferredLanguages: selectedLocale.rLanguages)
        let sheetViewModel = SheetAlertPresentableViewModel(
            title: title,
            subtitle: subtitle,
            actions: [closeAction]
        )
        router.present(viewModel: sheetViewModel, from: view)
    }
}

// MARK: - ChainAssetListInteractorOutput

extension ChainAssetListPresenter: ChainAssetListInteractorOutput {
    func snapshotWasBuilded(count: Int) {
        view?.runtimesBuilded(count: count)
    }

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

                guard chainAssets?.count == accountInfos.keys.count else {
                    return
                }
                accountInfosFetched = true
                provideViewModel()
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
        pricesFetched = filters.contains(where: { filter in
            if case ChainAssetsFetching.Filter.search = filter {
                return true
            }
            return false
        })
        accountInfosFetched = false
        accountInfos = [:]

        filters.isNotEmpty ? (displayType = .chain) : (displayType = .assetChains)
        interactor.updateChainAssets(using: filters, sorts: sorts)
    }
}
