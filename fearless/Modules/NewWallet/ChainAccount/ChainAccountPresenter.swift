import Foundation
import SoraFoundation
import BigInt

final class ChainAccountPresenter {
    weak var view: ChainAccountViewProtocol?
    let wireframe: ChainAccountWireframeProtocol
    let interactor: ChainAccountInteractorInputProtocol
    let viewModelFactory: ChainAccountViewModelFactoryProtocol
    let logger: LoggerProtocol
    let asset: AssetModel
    let chain: ChainModel
    let selectedMetaAccount: MetaAccountModel

    private var accountInfo: AccountInfo?
    private var priceData: PriceData?
    private var minimumBalance: BigUInt?
    private var balanceLocks: BalanceLocks?

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
        asset: AssetModel,
        chain: ChainModel,
        selectedMetaAccount: MetaAccountModel
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.asset = asset
        self.chain = chain
        self.selectedMetaAccount = selectedMetaAccount
    }

    func provideViewModel() {
        let accountBalanceViewModel = viewModelFactory.buildAccountBalanceViewModel(
            accountInfo: accountInfo,
            priceData: priceData,
            asset: asset,
            locale: selectedLocale
        )

        let assetInfoViewModel = viewModelFactory.buildAssetInfoViewModel(
            chain: chain,
            assetModel: asset,
            priceData: priceData,
            locale: selectedLocale
        )

        let chainOptionsViewModel = viewModelFactory.buildChainOptionsViewModel(chain: chain)

        let allAssets = Array(chain.assets)
        let chainAsset = allAssets.first(where: { $0.assetId == asset.id })

        let chainAccountViewModel = viewModelFactory.buildChainAccountViewModel(
            accountBalanceViewModel: accountBalanceViewModel,
            assetInfoViewModel: assetInfoViewModel,
            chainOptionsViewModel: chainOptionsViewModel,
            chainAssetModel: chainAsset
        )

        view?.didReceiveState(.loaded(chainAccountViewModel))
    }
}

private extension ChainAccountPresenter {
    func getPurchaseActions() -> [PurchaseAction] {
        var actions: [PurchaseAction] = []

        if let address = selectedMetaAccount.fetch(for: chain.accountRequest())?.toAddress() {
            let allAssets = Array(chain.assets)
            let chainAsset = allAssets.first(where: { $0.assetId == asset.id })

            var availableProviders: [PurchaseProviderProtocol] = []
            chainAsset?.purchaseProviders?.compactMap { $0 }.forEach {
                switch $0 {
                case .moonpay:
                    availableProviders.append(moonpayProvider)
                case .ramp:
                    availableProviders.append(rampProvider)
                }
            }

            let providersAggregator = PurchaseAggregator(providers: availableProviders)
            actions = providersAggregator.buildPurchaseActions(asset: asset, address: address)
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
            asset: asset,
            chain: chain,
            selectedMetaAccount: selectedMetaAccount
        )
    }

    func didTapReceiveButton() {
        wireframe.presentReceiveFlow(
            from: view,
            asset: asset,
            chain: chain,
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

    func didTapInfoButton() {
        print(accountInfo)
        if let info = accountInfo,
           let free = Decimal.fromSubstratePerbill(value: info.data.free),
           let reserved = Decimal.fromSubstratePerbill(value: info.data.reserved),
           let miscFrozen = Decimal.fromSubstratePerbill(value: info.data.miscFrozen),
           let feeFrozen = Decimal.fromSubstratePerbill(value: info.data.feeFrozen),
           let minBalance = minimumBalance,
           let decimalMinBalance = Decimal.fromSubstratePerbill(value: minBalance),
           let locks = balanceLocks {
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
                priceChange: priceData?.usdDayChange ?? 0,
                minimalBalance: decimalMinBalance,
                balanceLocks: locks
            )
            wireframe.presentLockedInfo(
                from: view,
                balanceContext: balanceContext,
                info: asset.displayInfo
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
