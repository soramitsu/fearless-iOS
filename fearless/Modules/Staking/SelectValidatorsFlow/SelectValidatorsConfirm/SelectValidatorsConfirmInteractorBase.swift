import Foundation
import RobinHood
import BigInt

class SelectValidatorsConfirmInteractorBase: SelectValidatorsConfirmInteractorInputProtocol,
    StakingDurationFetching {
    weak var presenter: SelectValidatorsConfirmInteractorOutputProtocol!

    let balanceAccountId: AccountId
    let runtimeService: RuntimeCodingServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let durationOperationFactory: StakingDurationOperationFactoryProtocol
    let signer: SigningWrapperProtocol
    let operationManager: OperationManagerProtocol
    let asset: AssetModel
    let chain: ChainModel
    let selectedAccount: MetaAccountModel
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?

    init(
        balanceAccountId: AccountId,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        durationOperationFactory: StakingDurationOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        signer: SigningWrapperProtocol,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        self.balanceAccountId = balanceAccountId
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.durationOperationFactory = durationOperationFactory
        self.operationManager = operationManager
        self.signer = signer
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
    }

    // MARK: - SelectValidatorsConfirmInteractorInputProtocol

    func setup() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        accountInfoSubscriptionAdapter.subscribe(chain: chain, accountId: balanceAccountId, handler: self)

        minBondProvider = subscribeToMinNominatorBond(for: chain.chainId)

        counterForNominatorsProvider = subscribeToCounterForNominators(for: chain.chainId)

        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: chain.chainId)

        fetchStakingDuration(
            runtimeCodingService: runtimeService,
            operationFactory: durationOperationFactory,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveStakingDuration(result: result)
        }
    }

    func submitNomination() {}

    func estimateFee() {}
}

extension SelectValidatorsConfirmInteractorBase: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveMinBond(result: result)
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveCounterForNominators(result: result)
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveMaxNominatorsCount(result: result)
    }
}

extension SelectValidatorsConfirmInteractorBase: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension SelectValidatorsConfirmInteractorBase: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePrice(result: result)
    }
}
