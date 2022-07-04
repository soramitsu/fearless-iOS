import Foundation
import SoraFoundation
import BigInt

final class ChainAccountPresenter {
    weak var view: ChainAccountViewProtocol?
    let wireframe: ChainAccountWireframeProtocol
    let interactor: ChainAccountInteractorInputProtocol
    let viewModelFactory: ChainAccountViewModelFactoryProtocol
    let logger: LoggerProtocol
    var chainAsset: ChainAsset {
        interactor.chainAsset
    }

    let selectedMetaAccount: MetaAccountModel
    weak var moduleOutput: ChainAccountModuleOutput?

    private var accountInfo: AccountInfo?
    private var priceData: PriceData?
    private var minimumBalance: BigUInt?
    private var balanceLocks: BalanceLocks?
    private var currency: Currency?

    private lazy var rampProvider = RampProvider()
    private lazy var moonpayProvider: PurchaseProviderProtocol = {
        let config: ApplicationConfigProtocol = ApplicationConfig.shared
        let moonpaySecretKeyData = Data(MoonPayKeys.secretKey.utf8)
        return MoonpayProviderFactory().createProvider(
            with: moonpaySecretKeyData,
            apiKey: config.moonPayApiKey
        )
    }()

    init(
        interactor: ChainAccountInteractorInputProtocol,
        wireframe: ChainAccountWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        logger: LoggerProtocol,
        selectedMetaAccount: MetaAccountModel,
        moduleOutput: ChainAccountModuleOutput?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.selectedMetaAccount = selectedMetaAccount
        self.moduleOutput = moduleOutput
    }

    func provideViewModel() {
        guard let currency = currency else {
            return
        }

        let accountBalanceViewModel = viewModelFactory.buildAccountBalanceViewModel(
            accountInfo: accountInfo,
            priceData: priceData,
            asset: chainAsset.asset,
            locale: selectedLocale,
            currency: currency
        )

        let assetInfoViewModel = viewModelFactory.buildAssetInfoViewModel(
            chain: chainAsset.chain,
            assetModel: chainAsset.asset,
            priceData: priceData,
            locale: selectedLocale,
            currency: currency
        )

        let chainOptionsViewModel = viewModelFactory.buildChainOptionsViewModel(chain: chainAsset.chain)

        let allAssets = Array(chainAsset.chain.assets)
        let chainAssetModel = allAssets.first(where: { $0.assetId == chainAsset.asset.id })

        let chainAccountViewModel = viewModelFactory.buildChainAccountViewModel(
            accountBalanceViewModel: accountBalanceViewModel,
            assetInfoViewModel: assetInfoViewModel,
            chainOptionsViewModel: chainOptionsViewModel,
            chainAssetModel: chainAssetModel
        )

        view?.didReceiveState(.loaded(chainAccountViewModel))
    }
}

extension ChainAccountPresenter: ChainAccountModuleInput {}

private extension ChainAccountPresenter {
    func getPurchaseActions() -> [PurchaseAction] {
        var actions: [PurchaseAction] = []

        if let address = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            let allAssets = Array(chainAsset.chain.assets)
            let chainAssetModel = allAssets.first(where: { $0.assetId == chainAsset.asset.id })

            var availableProviders: [PurchaseProviderProtocol] = []
            chainAssetModel?.purchaseProviders.forEach {
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
}

extension ChainAccountPresenter: ChainAccountPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func didTapBackButton() {
        wireframe.close(view: view)
    }

    func didTapSendButton() {
        wireframe.presentSendFlow(
            from: view,
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            selectedMetaAccount: selectedMetaAccount,
            transferFinishBlock: nil
        )
    }

    func didTapReceiveButton() {
        wireframe.presentReceiveFlow(
            from: view,
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            selectedMetaAccount: selectedMetaAccount
        )
    }

    func didTapBuyButton() {
        wireframe.presentBuyFlow(
            from: view,
            items: getPurchaseActions(),
            delegate: self
        )
    }

    func didTapOptionsButton() {
        guard let address = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
            return
        }
        interactor.getAvailableExportOptions(for: address)
    }

    func didTapInfoButton() {
        if let info = accountInfo,
           let free = Decimal.fromSubstratePerbill(value: info.data.free),
           let reserved = Decimal.fromSubstratePerbill(value: info.data.reserved),
           let miscFrozen = Decimal.fromSubstratePerbill(value: info.data.miscFrozen),
           let feeFrozen = Decimal.fromSubstratePerbill(value: info.data.feeFrozen),
           let minBalance = minimumBalance,
           let decimalMinBalance = Decimal.fromSubstratePerbill(value: minBalance),
           let locks = balanceLocks,
           let currency = currency {
            var price: Decimal = 0
            if let priceData = priceData, let decimalPrice = Decimal(string: priceData.price) {
                price = decimalPrice
            }
            let balanceContext = BalanceContext(
                free: free,
                reserved: reserved,
                miscFrozen: miscFrozen,
                feeFrozen: feeFrozen,
                price: price,
                priceChange: priceData?.fiatDayChange ?? 0,
                minimalBalance: decimalMinBalance,
                balanceLocks: locks
            )
            wireframe.presentLockedInfo(
                from: view,
                balanceContext: balanceContext,
                info: chainAsset.asset.displayInfo,
                currency: currency
            )
        }
    }
}

extension ChainAccountPresenter: ChainAccountInteractorOutputProtocol {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for _: ChainModel.Id) {
        switch result {
        case let .success(accountInfo):
            self.accountInfo = accountInfo
            provideViewModel()
        case let .failure(error):
            logger.error("ChainAccountPresenter:didReceiveAccountInfo:error:\(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>, for _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            if priceData != nil {
                self.priceData = priceData
                provideViewModel()
            }
        case let .failure(error):
            logger.error("ChainAccountPresenter:didReceivePriceData:error:\(error)")
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

    func didReceiveBalanceLocks(result: Result<BalanceLocks?, Error>) {
        switch result {
        case let .success(balanceLocks):
            self.balanceLocks = balanceLocks
        case let .failure(error):
            logger.error("Did receive balance locks error: \(error)")
        }
    }

    func didReceiveExportOptions(options: [ExportOption]) {
        let items: [ChainAction] = [.export, .switchNode, .copyAddress, .replace]
        let selectionCallback: ModalPickerSelectionCallback = { [weak self] selectedIndex in
            guard let self = self else { return }
            let action = items[selectedIndex]
            switch action {
            case .export:
                guard let address =
                    self.selectedMetaAccount.fetch(for: self.chainAsset.chain.accountRequest())?.toAddress()
                else { return }
                self.wireframe.showExport(
                    for: address,
                    chain: self.chainAsset.chain,
                    options: options,
                    locale: self.selectedLocale,
                    wallet: self.selectedMetaAccount,
                    from: self.view
                )
            case .switchNode:
                self.wireframe.presentNodeSelection(
                    from: self.view,
                    chain: self.chainAsset.chain
                )
            case .copyAddress:
                UIPasteboard.general.string =
                    self.selectedMetaAccount.fetch(for: self.chainAsset.chain.accountRequest())?.toAddress()

                let title = R.string.localizable.commonCopied(preferredLanguages: self.selectedLocale.rLanguages)
                self.wireframe.presentSuccessNotification(title, from: self.view)
            case .replace:
                let model = UniqueChainModel(meta: self.selectedMetaAccount, chain: self.chainAsset.chain)
                let options: [ReplaceChainOption] = ReplaceChainOption.allCases
                self.wireframe.showUniqueChainSourceSelection(
                    from: self.view,
                    items: options,
                    callback: { [weak self] selectedIndex in
                        let option = options[selectedIndex]
                        switch option {
                        case .create:
                            self?.wireframe.showCreate(uniqueChainModel: model, from: self?.view)
                        case .import:
                            self?.wireframe.showImport(uniqueChainModel: model, from: self?.view)
                        }
                    }
                )
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

    func didReceive(currency: Currency) {
        self.currency = currency
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
