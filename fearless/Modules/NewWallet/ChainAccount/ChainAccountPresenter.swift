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

    let wallet: MetaAccountModel
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

    private var balanceLocks: BalanceLocks?
    private var balance: WalletBalanceInfo?
    private var minimumBalance: BigUInt?
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
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.wallet = wallet
        self.moduleOutput = moduleOutput
        self.balanceInfoModule = balanceInfoModule
        self.balanceViewModelFactory = balanceViewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        let chainAccountViewModel = viewModelFactory.buildChainAccountViewModel(
            chainAsset: chainAsset,
            wallet: wallet
        )

        DispatchQueue.main.async {
            self.view?.didReceiveState(.loaded(chainAccountViewModel))
        }
    }

    private func provideBalanceViewModel() {
        var accountInfo: AccountInfo?

        if
            let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
            let optionalAccountInfo = balance?.accountInfos[chainAsset.uniqueKey(accountId: accountId)],
            let wrappedAccountInfo = optionalAccountInfo {
            accountInfo = wrappedAccountInfo
        }

        let free = accountInfo?.data.sendAvailable ?? BigUInt.zero
        let locked = accountInfo?.data.locked ?? BigUInt.zero

        let priceData = balance?.prices.first(where: { $0.priceId == chainAsset.asset.priceId })
        let freeBalance = Decimal.fromSubstrateAmount(
            free,
            precision: Int16(chainAsset.asset.precision)
        ) ?? Decimal.zero
        let lockedBalance = Decimal.fromSubstrateAmount(
            locked,
            precision:
            Int16(chainAsset.asset.precision)
        ) ?? Decimal.zero

        let transferrableValue = balanceViewModelFactory.balanceFromPrice(freeBalance, priceData: priceData, usageCase: .detailsCrypto)
        let lockedValue = balanceViewModelFactory.balanceFromPrice(lockedBalance, priceData: priceData, usageCase: .detailsCrypto)

        let balanceViewModel = ChainAccountBalanceViewModel(
            transferrableValue: transferrableValue,
            lockedValue: lockedValue,
            hasLockedTokens: lockedBalance > Decimal.zero
        )
        view?.didReceive(balanceViewModel: balanceViewModel)
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

    private func createBalanceContext() -> BalanceContext? {
        guard let balance = balance else {
            return nil
        }

        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
           let accountInfo = balance.accountInfos[chainAsset.uniqueKey(accountId: accountId)],
           let info = accountInfo,
           let free = Decimal.fromSubstratePerbill(value: info.data.free),
           let reserved = Decimal.fromSubstratePerbill(value: info.data.reserved),
           let frozen = Decimal.fromSubstratePerbill(value: info.data.frozen),
           let minBalance = minimumBalance,
           let decimalMinBalance = Decimal.fromSubstratePerbill(value: minBalance),
           let locks = balanceLocks {
            var price: Decimal = 0
            let priceData = balance.prices.first(where: { $0.priceId == chainAsset.asset.priceId })
            if let data = priceData, let decimalPrice = Decimal(string: data.price) {
                price = decimalPrice
            }
            return BalanceContext(
                free: free,
                reserved: reserved,
                frozen: frozen,
                price: price,
                priceChange: priceData?.fiatDayChange ?? 0,
                minimalBalance: decimalMinBalance,
                balanceLocks: locks
            )
        }
        return nil
    }
}

extension ChainAccountPresenter: ChainAccountModuleInput {}

extension ChainAccountPresenter: ChainAccountPresenterProtocol {
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
        wireframe.showSelectNetwork(
            from: view,
            wallet: wallet,
            selectedChainId: chainAsset.chain.chainId,
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
        guard let balance = balance else {
            return
        }

        if let balanceContext = createBalanceContext() {
            wireframe.presentLockedInfo(
                from: view,
                balanceContext: balanceContext,
                info: chainAsset.asset.displayInfo,
                currency: balance.currency
            )
        }
    }
}

extension ChainAccountPresenter: ChainAccountInteractorOutputProtocol {
    func didReceiveExportOptions(options: [ExportOption]) {
        let items: [ChainAction] = [.export, .switchNode, .replace]
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

    func didUpdate(chainAsset: ChainAsset) {
        provideViewModel()
        balanceInfoModule.replace(infoType: .chainAsset(
            wallet: wallet,
            chainAsset: chainAsset
        ))
        moduleOutput?.updateTransactionHistory(for: chainAsset)
    }

    func didReceiveBalanceLocks(result: Result<BalanceLocks?, Error>) {
        switch result {
        case let .success(balanceLocks):
            self.balanceLocks = balanceLocks
            provideBalanceViewModel()
        case let .failure(error):
            logger.error("Did receive balance locks error: \(error)")
        }
    }

    func didReceiveWalletBalancesResult(_ result: WalletBalancesResult) {
        switch result {
        case let .success(balances):
            balance = balances[wallet.metaId]
            provideBalanceViewModel()
        case let .failure(error):
            logger.error(error.localizedDescription)
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            self.minimumBalance = minimumBalance
        case let .failure(error):
            logger.error("Did receive minimum balance error: \(error)")
        }
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

        interactor.update(chain: chain)
    }
}
