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
    private weak var moduleOutput: ChainAssetListModuleOutput?

    private let viewModelFactory: ChainAssetListViewModelFactoryProtocol
    private var wallet: MetaAccountModel
    private var chainAssets: [ChainAsset]?

    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private var prices: PriceDataUpdated = ([], false)
    private var displayType: AssetListDisplayType = .assetChains
    private var chainsWithIssues: [ChainModel] = []
    private var accountInfosFetched = false
    private var pricesFetched = false

    private lazy var factoryOperationQueue: OperationQueue = {
        OperationQueue()
    }()

    // MARK: - Constructors

    init(
        moduleOutput: ChainAssetListModuleOutput?,
        interactor: ChainAssetListInteractorInput,
        router: ChainAssetListRouterInput,
        localizationManager: LocalizationManagerProtocol,
        wallet: MetaAccountModel,
        viewModelFactory: ChainAssetListViewModelFactoryProtocol
    ) {
        self.moduleOutput = moduleOutput
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
                chainsWithIssues: self.chainsWithIssues.map { $0.chainId }
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
        moduleOutput?.didTapAction(actionType: actionType, viewModel: viewModel)
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
            router.present(error: error, from: view, locale: selectedLocale)
        }

        pricesFetched = true
        provideViewModel()
    }

    func didReceiveChainsWithNetworkIssues(_ chains: [ChainModel]) {
        chainsWithIssues = chains
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
        pricesFetched = false
        accountInfosFetched = false
        accountInfos = [:]

        filters.isNotEmpty ? (displayType = .chain) : (displayType = .assetChains)
        interactor.updateChainAssets(using: filters, sorts: sorts)
    }
}
