import RobinHood
import SoraKeystore

final class StakingRebondSetupInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRebondSetupInteractorOutputProtocol!

    let settings: SettingsManagerProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let feeProxy: ExtrinsicFeeProxyProtocol
    let chain: Chain
    let assetId: WalletAssetId

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?
//    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?

    init(
        settings: SettingsManagerProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
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
        self.runtimeCodingService = runtimeCodingService
        self.operationManager = operationManager
        self.accountRepository = accountRepository
        self.feeProxy = feeProxy
        self.chain = chain
        self.assetId = assetId
    }
}

extension StakingRebondSetupInteractor: StakingRebondSetupInteractorInputProtocol {
    func setup() {
        if let address = settings.selectedAccount?.address {
            stashItemProvider = subscribeToStashItemProvider(for: address)
        }

        priceProvider = subscribeToPriceProvider(for: assetId)

        electionStatusProvider = subscribeToElectionStatusProvider(
            chain: chain,
            runtimeService: runtimeCodingService
        )

        feeProxy.delegate = self
    }
}

extension StakingRebondSetupInteractor: SubstrateProviderSubscriber,
    SubstrateProviderSubscriptionHandler,
    SingleValueProviderSubscriber,
    SingleValueSubscriptionHandler,
    AnyProviderAutoCleaning,
    ExtrinsicFeeProxyDelegate {
    // MARK: - SubstrateProviderSubscriptionHandler

    func handleStashItem(result _: Result<StashItem?, Error>) {
        #warning("Not Implemented")
    }

    // MARK: - SingleValueSubscriptionHandler

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }

//    func handleAccountInfo(result: Result<DyAccountInfo?, Error>, address: AccountAddress)

    func handleElectionStatus(result: Result<ElectionStatus?, Error>, chain _: Chain) {
        presenter.didReceiveElectionStatus(result: result)
    }

//    func handleLedgerInfo(result: Result<DyStakingLedger?, Error>, address: AccountAddress)

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chain _: Chain) {
        presenter.didReceiveActiveEra(result: result)
    }

    // MARK: - ExtrinsicFeeProxyDelegate

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
