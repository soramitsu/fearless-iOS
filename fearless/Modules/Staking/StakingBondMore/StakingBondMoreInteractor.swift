import RobinHood
import IrohaCrypto
import BigInt
import SoraKeystore

final class StakingBondMoreInteractor: AccountFetching {
    weak var presenter: StakingBondMoreInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol

    private let settings: SettingsManagerProtocol
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let extrinsicServiceFactoryProtocol: ExtrinsicServiceFactoryProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let chain: Chain
    private let assetId: WalletAssetId

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?
    private var extrinsicService: ExtrinsicServiceProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        settings: SettingsManagerProtocol,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        extrinsicServiceFactoryProtocol: ExtrinsicServiceFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        chain: Chain,
        assetId: WalletAssetId
    ) {
        self.settings = settings
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.accountRepository = accountRepository
        self.extrinsicServiceFactoryProtocol = extrinsicServiceFactoryProtocol
        self.feeProxy = feeProxy
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.chain = chain
        self.assetId = assetId
    }

    func handleStashAccountItem(_ accountItem: AccountItem) {
        extrinsicService = extrinsicServiceFactoryProtocol.createService(accountItem: accountItem)
        estimateFee()
    }
}

extension StakingBondMoreInteractor: StakingBondMoreInteractorInputProtocol {
    func setup() {
        if let address = settings.selectedAccount?.address {
            stashItemProvider = subscribeToStashItemProvider(for: address)
        }

        priceProvider = subscribeToPriceProvider(for: assetId)
        electionStatusProvider = subscribeToElectionStatusProvider(chain: chain, runtimeService: runtimeService)

        feeProxy.delegate = self
    }

    func estimateFee() {
        guard let extrinsicService = extrinsicService,
              let amount = StakingConstants.maxAmount.toSubstrateAmount(
                  precision: chain.addressType.precision
              ) else {
            return
        }

        let bondExtra = callFactory.bondExtra(amount: amount)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: bondExtra.callName) { builder in
            try builder.adding(call: bondExtra)
        }
    }
}

extension StakingBondMoreInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler,
    SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &balanceProvider)

            presenter.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem {
                balanceProvider = subscribeToAccountInfoProvider(
                    for: stashItem.controller,
                    runtimeService: runtimeService
                )

                fetchAccount(
                    for: stashItem.stash,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(maybeStash) = result, let stash = maybeStash {
                        self?.handleStashAccountItem(stash)
                    }

                    self?.presenter.didReceiveStash(result: result)
                }

            } else {
                presenter.didReceiveAccountInfo(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
        }
    }

    func handleAccountInfo(result: Result<DyAccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }

    func handleElectionStatus(result: Result<ElectionStatus?, Error>, chain _: Chain) {
        presenter.didReceiveElectionStatus(result: result)
    }
}

extension StakingBondMoreInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
