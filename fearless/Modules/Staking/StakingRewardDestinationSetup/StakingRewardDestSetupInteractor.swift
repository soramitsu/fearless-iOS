import SoraKeystore
import RobinHood

final class StakingRewardDestSetupInteractor: AccountFetching {
    weak var presenter: StakingRewardDestSetupInteractorOutputProtocol!

    let settings: SettingsManagerProtocol
    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let feeProxy: ExtrinsicFeeProxyProtocol
    let chain: Chain

    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    private var extrinisicService: ExtrinsicServiceProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        settings: SettingsManagerProtocol,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        feeProxy: ExtrinsicFeeProxyProtocol,
        chain: Chain
    ) {
        self.settings = settings
        self.singleValueProviderFactory = singleValueProviderFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.accountRepository = accountRepository
        self.feeProxy = feeProxy
        self.chain = chain
    }

    private func handleController(accountItem: AccountItem) {
        extrinisicService = extrinsicServiceFactory.createService(accountItem: accountItem)

        estimateFee()
    }
}

extension StakingRewardDestSetupInteractor: StakingRewardDestSetupInteractorInputProtocol {
    func setup() {
        #warning("Not implemented")
        if let address = settings.selectedAccount?.address {
            stashItemProvider = subscribeToStashItemProvider(for: address)
        }

//        priceProvider = subscribeToPriceProvider(for: assetId)
        feeProxy.delegate = self
    }

    func estimateFee() {
        guard let extrinsicService = extrinisicService else { return }

        let setPayeeCall = callFactory.setPayee(for: .stash)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: setPayeeCall.callName) { builder in
            try builder.adding(call: setPayeeCall)
        }
    }
}

extension StakingRewardDestSetupInteractor: SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler, SingleValueProviderSubscriber, SingleValueSubscriptionHandler, AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)
//            clear(dataProvider: &ledgerProvider)

//            presenter.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem {
//                ledgerProvider = subscribeToLedgerInfoProvider(
//                    for: stashItem.controller,
//                    runtimeService: runtimeService
//                )

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

//                    self?.presenter.didReceiveController(result: result)
                }

            } else {
//                presenter.didReceiveStakingLedger(result: .success(nil))
//                presenter.didReceiveAccountInfo(result: .success(nil))
            }

        } catch {
//            presenter.didReceiveStashItem(result: .failure(error))
//            presenter.didReceiveAccountInfo(result: .failure(error))
//            presenter.didReceiveStakingLedger(result: .failure(error))
        }
    }
}

extension StakingRewardDestSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
