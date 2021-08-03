import RobinHood
import SoraKeystore

final class StakingRebondSetupInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRebondSetupInteractorOutputProtocol!

    let settings: SettingsManagerProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let feeProxy: ExtrinsicFeeProxyProtocol
    let chain: Chain
    let assetId: WalletAssetId

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var extrinisicService: ExtrinsicServiceProtocol?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        settings: SettingsManagerProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        feeProxy: ExtrinsicFeeProxyProtocol,
        chain: Chain,
        assetId: WalletAssetId
    ) {
        self.settings = settings
        self.substrateProviderFactory = substrateProviderFactory
        self.singleValueProviderFactory = singleValueProviderFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        runtimeService = runtimeCodingService
        self.operationManager = operationManager
        self.accountRepository = accountRepository
        self.feeProxy = feeProxy
        self.chain = chain
        self.assetId = assetId
    }

    private func handleController(accountItem: AccountItem) {
        extrinisicService = extrinsicServiceFactory.createService(accountItem: accountItem)

        estimateFee()
    }
}

extension StakingRebondSetupInteractor: StakingRebondSetupInteractorInputProtocol {
    func setup() {
        if let address = settings.selectedAccount?.address {
            stashItemProvider = subscribeToStashItemProvider(for: address)
        }

        priceProvider = subscribeToPriceProvider(for: assetId)

        activeEraProvider = subscribeToActiveEraProvider(for: chain, runtimeService: runtimeService)

        feeProxy.delegate = self
    }

    func estimateFee() {
        guard let extrinsicService = extrinisicService,
              let amount = StakingConstants.maxAmount.toSubstrateAmount(
                  precision: chain.addressType.precision
              ) else {
            return
        }

        let rebondCall = callFactory.rebond(amount: amount)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: rebondCall.callName) { builder in
            try builder.adding(call: rebondCall)
        }
    }
}

extension StakingRebondSetupInteractor: SubstrateProviderSubscriber,
    SubstrateProviderSubscriptionHandler,
    SingleValueProviderSubscriber,
    SingleValueSubscriptionHandler,
    AnyProviderAutoCleaning,
    ExtrinsicFeeProxyDelegate {
    // MARK: - SubstrateProviderSubscriptionHandler

    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)

            presenter.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem {
                ledgerProvider = subscribeToLedgerInfoProvider(
                    for: stashItem.controller,
                    runtimeService: runtimeService
                )

                accountInfoProvider = subscribeToAccountInfoProvider(
                    for: stashItem.controller,
                    runtimeService: runtimeService
                )

                fetchAccount(
                    for: stashItem.controller,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(maybeController) = result, let controller = maybeController {
                        self?.handleController(accountItem: controller)
                    }

                    self?.presenter.didReceiveController(result: result)
                }

            } else {
                presenter.didReceiveStakingLedger(result: .success(nil))
                presenter.didReceiveAccountInfo(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
        }
    }

    // MARK: - SingleValueSubscriptionHandler

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }

    func handleLedgerInfo(result: Result<StakingLedger?, Error>, address _: AccountAddress) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chain _: Chain) {
        presenter.didReceiveActiveEra(result: result)
    }

    // MARK: - ExtrinsicFeeProxyDelegate

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
