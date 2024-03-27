import Foundation
import SoraFoundation
import BigInt
import SSFModels

final class ChainAccountPresenter {
    weak var view: ChainAccountViewProtocol?
    let wireframe: ChainAccountWireframeProtocol
    let interactor: ChainAccountInteractorInputProtocol
    let viewModelFactory: ChainAccountViewModelFactoryProtocol
    let logger: LoggerProtocol
    var chainAsset: ChainAsset {
        interactor.chainAsset
    }

    var mode: ChainAccountViewMode

    var wallet: MetaAccountModel
    weak var moduleOutput: ChainAccountModuleOutput?
    private let balanceInfoModule: BalanceInfoModuleInput

    private lazy var rampProvider = RampProvider()
    private lazy var moonpayProvider: PurchaseProviderProtocol = {
        let config: ApplicationConfigProtocol = ApplicationConfig.shared
        let moonpaySecretKeyData = Data(MoonPayKeys.secretKey.utf8)
        return MoonpayProviderFactory().createProvider(
            with: moonpaySecretKeyData,
            apiKey: config.moonPayApiKey
        )
    }()

    private var frozen: NoneStateOptional<Decimal?> = .none
    private var balanceLocks: NoneStateOptional<Decimal?> = .none
    private var balance: NoneStateOptional<WalletBalanceInfo?> = .none
    private var minimumBalance: NoneStateOptional<BigUInt?> = .none
    private var accountInfo: NoneStateOptional<AccountInfo?> = .none
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        interactor: ChainAccountInteractorInputProtocol,
        wireframe: ChainAccountWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        logger: LoggerProtocol,
        wallet: MetaAccountModel,
        moduleOutput: ChainAccountModuleOutput?,
        balanceInfoModule: BalanceInfoModuleInput,
        localizationManager: LocalizationManagerProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        mode: ChainAccountViewMode
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.wallet = wallet
        self.moduleOutput = moduleOutput
        self.balanceInfoModule = balanceInfoModule
        self.balanceViewModelFactory = balanceViewModelFactory
        self.mode = mode
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        let chainAccountViewModel = viewModelFactory.buildChainAccountViewModel(
            chainAsset: chainAsset,
            wallet: wallet,
            mode: mode
        )

        DispatchQueue.main.async {
            self.view?.didReceiveState(.loaded(chainAccountViewModel))
        }
    }

    private func provideBalanceViewModel() {
        guard
            case var .value(accountInfoValue) = accountInfo,
            case let .value(frozenValue) = frozen,
            case let .value(balanceValue) = balance,
            case let .value(balanceLocksValue) = balanceLocks else {
            DispatchQueue.main.async { [weak self] in
                self?.view?.didReceive(balanceViewModel: nil)
            }
            return
        }

        if
            let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
            let optionalAccountInfo = balanceValue?.accountInfos[chainAsset.uniqueKey(accountId: accountId)],
            let wrappedAccountInfo = optionalAccountInfo {
            accountInfoValue = wrappedAccountInfo
        }

        let free = accountInfoValue?.data.sendAvailable ?? BigUInt.zero
        let priceData = balanceValue?.prices.first(where: { $0.priceId == chainAsset.asset.priceId })
        let freeBalance = Decimal.fromSubstrateAmount(
            free,
            precision: Int16(chainAsset.asset.precision)
        ) ?? Decimal.zero

        let transferrableBalance = freeBalance - frozenValue.or(.zero)
        let transferrableValue = balanceViewModelFactory.balanceFromPrice(transferrableBalance, priceData: priceData, usageCase: .detailsCrypto)
        let totalLocked = balanceLocksValue.or(.zero) + frozenValue.or(.zero)
        let lockedValue = balanceViewModelFactory.balanceFromPrice(totalLocked, priceData: priceData, usageCase: .detailsCrypto)

        let balanceViewModel = ChainAccountBalanceViewModel(
            transferrableValue: transferrableValue,
            lockedValue: lockedValue,
            hasLockedTokens: totalLocked > Decimal.zero
        )

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceive(balanceViewModel: balanceViewModel)
        }
    }

    private func getPurchaseActions() -> [PurchaseAction] {
        var actions: [PurchaseAction] = []

        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            let allAssets = Array(chainAsset.chain.assets)
            let chainAssetModel = allAssets.first(where: { $0.id == chainAsset.asset.id })

            var availableProviders: [PurchaseProviderProtocol] = []
            chainAssetModel?.purchaseProviders?.compactMap { $0 }.forEach {
                switch $0 {
                case .moonpay:
                    availableProviders.append(moonpayProvider)
                case .ramp:
                    availableProviders.append(rampProvider)
                }
            }

            let providersAggregator = PurchaseAggregator(providers: availableProviders)
            actions = providersAggregator.buildPurchaseActions(asset: chainAsset.asset, address: address)
        }
        return actions
    }

    private func startReplaceAccountFlow() {
        func showCreateFlow() {
            let rLanguages = localizationManager?.selectedLocale.rLanguages
            let actionTitle = R.string.localizable.commonOk(preferredLanguages: rLanguages)
            let action = SheetAlertPresentableAction(title: actionTitle) { [weak self] in
                self?.wireframe.showCreate(uniqueChainModel: model, from: self?.view)
            }

            let title = R.string.localizable.commonNoScreenshotTitle(preferredLanguages: rLanguages)
            let message = R.string.localizable.commonNoScreenshotMessage(preferredLanguages: rLanguages)
            let viewModel = SheetAlertPresentableViewModel(
                title: title,
                message: message,
                actions: [action],
                closeAction: nil,
                icon: R.image.iconWarningBig()
            )

            wireframe.present(viewModel: viewModel, from: view)
        }

        let model = UniqueChainModel(meta: wallet, chain: chainAsset.chain)
        let options: [ReplaceChainOption] = ReplaceChainOption.allCases
        wireframe.showUniqueChainSourceSelection(
            from: view,
            items: options,
            callback: { [weak self] selectedIndex in
                let option = options[selectedIndex]
                switch option {
                case .create:
                    showCreateFlow()
                case .import:
                    self?.wireframe.showImport(uniqueChainModel: model, from: self?.view)
                }
            }
        )
    }
}

extension ChainAccountPresenter: ChainAccountModuleInput {}

extension ChainAccountPresenter: ChainAccountPresenterProtocol {
    func didPullToRefresh() {
        interactor.updateData()
    }

    func addressDidCopied() {
        wireframe.presentStatus(
            with: AddressCopiedEvent(locale: selectedLocale),
            animated: true
        )
    }

    func setup() {
        interactor.setup()
        provideViewModel()
    }

    func didTapBackButton() {
        wireframe.close(view: view)
    }

    func didTapSendButton() {
        wireframe.presentSendFlow(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    func didTapReceiveButton() {
        wireframe.presentReceiveFlow(
            from: view,
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            wallet: wallet
        )
    }

    func didTapBuyButton() {
        wireframe.presentBuyFlow(
            from: view,
            items: getPurchaseActions(),
            delegate: self
        )
    }

    func didTapCrossChainButton() {
        wireframe.presentCrossChainFlow(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    func didTapOptionsButton() {
        guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
            return
        }
        interactor.getAvailableExportOptions(for: address)
    }

    func didTapSelectNetwork() {
        let selectedChainId: ChainModel.Id? = mode == .simple ? nil : chainAsset.chain.chainId
        wireframe.showSelectNetwork(
            from: view,
            wallet: wallet,
            selectedChainId: selectedChainId,
            chainModels: interactor.availableChainAssets.map(\.chain).withoutDuplicates(),
            delegate: self
        )
    }

    func didTapPolkaswapButton() {
        wireframe.showPolkaswap(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    func didTapLockedInfoButton() {
        wireframe.presentLockedInfo(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }
}

extension ChainAccountPresenter: ChainAccountInteractorOutputProtocol {
    func didReceiveAssetFrozen(_ frozen: Decimal?) {
        self.frozen = .value(frozen)
        provideBalanceViewModel()
    }

    func didReceiveAssetFrozenError(_ error: Error) {
        frozen = .value(nil)
        logger.customError(error)
    }

    func didReceiveExportOptions(options: [ExportOption]) {
        var items: [ChainAction] = []
        items.append(.export)
        if !chainAsset.chain.isEthereum { items.append(.switchNode) }
        items.append(.replace)
        if interactor.checkIsClaimAvailable() { items.append(.claimCrowdloanRewards) }

        let selectionCallback: ModalPickerSelectionCallback = { [weak self] selectedIndex in
            guard let self = self else { return }
            let action = items[selectedIndex]
            switch action {
            case .export:
                guard let address =
                    self.wallet.fetch(for: self.chainAsset.chain.accountRequest())?.toAddress()
                else { return }
                self.wireframe.showExport(
                    for: address,
                    chain: self.chainAsset.chain,
                    options: options,
                    locale: self.selectedLocale,
                    wallet: self.wallet,
                    from: self.view
                )
            case .switchNode:
                self.wireframe.presentNodeSelection(
                    from: self.view,
                    chain: self.chainAsset.chain
                )
            case .replace:
                self.startReplaceAccountFlow()
            case .claimCrowdloanRewards:
                self.wireframe.showClaimCrowdloanRewardsFlow(from: self.view, chainAsset: self.chainAsset, wallet: self.wallet)
            default:
                break
            }
        }

        wireframe.presentChainActionsFlow(
            from: view,
            items: items,
            chain: chainAsset.chain,
            callback: selectionCallback
        )
    }

    func didReceive(availableChainAssets: [ChainAsset]) {
        guard mode == .simple else {
            return
        }

        balanceInfoModule.replace(infoType: .chainAssets(chainAssets: availableChainAssets, wallet: wallet))
    }

    func didUpdate(chainAsset: ChainAsset) {
        provideViewModel()

        if mode == .extended {
            balanceInfoModule.replace(infoType: .chainAsset(
                wallet: wallet,
                chainAsset: chainAsset
            ))
        }

        moduleOutput?.updateTransactionHistory(for: chainAsset)
    }

    func didReceiveBalanceLocks(_ balanceLocks: Decimal?) {
        self.balanceLocks = .value(balanceLocks)
        provideBalanceViewModel()
    }

    func didReceiveBalanceLocksError(_ error: Error) {
        balanceLocks = .value(nil)
        logger.error("Did receive balance locks error: \(error)")
    }

    func didReceiveWalletBalancesResult(_ result: WalletBalancesResult) {
        switch result {
        case let .success(balances):
            balance = .value(balances[wallet.metaId])
            provideBalanceViewModel()
        case let .failure(error):
            balance = .value(nil)
            logger.error(error.localizedDescription)
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            self.minimumBalance = .value(minimumBalance)
        case let .failure(error):
            minimumBalance = .value(nil)
            logger.error("Did receive minimum balance error: \(error)")
        }
    }

    func didReceive(accountInfo: AccountInfo?, for _: ChainAsset, accountId _: AccountId) {
        self.accountInfo = .value(accountInfo)
        provideBalanceViewModel()
    }

    func didReceiveWallet(wallet: MetaAccountModel) {
        self.wallet = wallet
        provideViewModel()
    }
}

extension ChainAccountPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension ChainAccountPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        wireframe.presentPurchaseWebView(from: view, action: getPurchaseActions()[index])
    }
}

extension ChainAccountPresenter: SelectNetworkDelegate {
    func chainSelection(
        view _: SelectNetworkViewInput,
        didCompleteWith chain: ChainModel?,
        contextTag _: Int?
    ) {
        guard let chain = chain else {
            return
        }

        switch mode {
        case .simple:
            let chainAsset = ChainAsset(chain: chain, asset: self.chainAsset.asset)
            wireframe.showDetails(from: view, chainAsset: chainAsset, wallet: wallet)
        case .extended:
            interactor.update(chain: chain)
        }
    }
}
