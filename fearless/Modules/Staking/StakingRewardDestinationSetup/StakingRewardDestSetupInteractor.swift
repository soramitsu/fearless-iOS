import SoraKeystore
import RobinHood

final class StakingRewardDestSetupInteractor: AccountFetching {
    weak var presenter: StakingRewardDestSetupInteractorOutputProtocol!

    let settings: SettingsManagerProtocol
    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let calculatorService: RewardCalculatorServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let feeProxy: ExtrinsicFeeProxyProtocol
    let assetId: WalletAssetId
    let chain: Chain

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?

    private var extrinisicService: ExtrinsicServiceProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        settings: SettingsManagerProtocol,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        calculatorService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        feeProxy: ExtrinsicFeeProxyProtocol,
        assetId: WalletAssetId,
        chain: Chain
    ) {
        self.settings = settings
        self.singleValueProviderFactory = singleValueProviderFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.calculatorService = calculatorService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.accountRepository = accountRepository
        self.feeProxy = feeProxy
        self.assetId = assetId
        self.chain = chain
    }

    private func handleController(accountItem: AccountItem) {
        extrinisicService = extrinsicServiceFactory.createService(accountItem: accountItem)

        estimateFee()
    }

    private func provideRewardCalculator() {
        let operation = calculatorService.fetchCalculatorOperation()

        operation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceiveCalculator(result: .success(engine))
                } catch {
                    self?.presenter.didReceiveCalculator(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(
            operations: [operation],
            in: .transient
        )
    }
}

extension StakingRewardDestSetupInteractor: StakingRewardDestSetupInteractorInputProtocol {
    func setup() {
        if let address = settings.selectedAccount?.address {
            stashItemProvider = subscribeToStashItemProvider(for: address)
        }

        priceProvider = subscribeToPriceProvider(for: assetId)

        provideRewardCalculator()

        feeProxy.delegate = self
    }

    func estimateFee() {
        guard let extrinsicService = extrinisicService else { return }

        let setPayeeCall = callFactory.setPayee(for: .stash)

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: setPayeeCall.callName
        ) { builder in
            try builder.adding(call: setPayeeCall)
        }
    }
}

extension StakingRewardDestSetupInteractor: SubstrateProviderSubscriber,
    SubstrateProviderSubscriptionHandler, SingleValueProviderSubscriber,
    SingleValueSubscriptionHandler, AnyProviderAutoCleaning {
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

                // TODO: Нужен ли accountInfo здесь?
                accountInfoProvider = subscribeToAccountInfoProvider(
                    for: stashItem.controller,
                    runtimeService: runtimeService
                )

                payeeProvider = subscribeToPayeeProvider(
                    for: stashItem.stash,
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
                //                presenter.didReceiveAccountInfo(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            //            presenter.didReceiveAccountInfo(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
        }
    }

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }

    func handleLedgerInfo(result: Result<DyStakingLedger?, Error>, address _: AccountAddress) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handlePayee(result: Result<RewardDestinationArg?, Error>, address _: AccountAddress) {
        presenter.didReceivePayee(result: result)
    }
}

extension StakingRewardDestSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
