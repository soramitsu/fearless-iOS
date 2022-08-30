import Foundation
import SoraFoundation

enum AssetListDisplayType {
    case chain
    case assetChains
}

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
        guard let chainAssets = chainAssets else {
            return
        }

        DispatchQueue.global().async {
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
        provideViewModel()
    }

    func didReceiveChainAssets(result: Result<[ChainAsset], Error>) {
        switch result {
        case let .success(chainAssets):
            self.chainAssets = chainAssets
            provideViewModel()
        case let .failure(error):
            DispatchQueue.main.async {
                self.router.present(error: error, from: self.view, locale: self.selectedLocale)
            }
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
        guard chainAssets?.count == accountInfos.keys.count else {
            return
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
        filters.isNotEmpty ? (displayType = .chain) : (displayType = .assetChains)
        interactor.updateChainAssets(using: filters, sorts: sorts)
    }
}
