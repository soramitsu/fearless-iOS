import Foundation
import RobinHood
import BigInt

class SelectValidatorsConfirmInteractorBase: SelectValidatorsConfirmInteractorInputProtocol,
    StakingDurationFetching {
    weak var presenter: SelectValidatorsConfirmInteractorOutputProtocol!

    let balanceAccountAddress: AccountAddress
    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let durationOperationFactory: StakingDurationOperationFactoryProtocol
    let signer: SigningWrapperProtocol
    let operationManager: OperationManagerProtocol
    let assetId: WalletAssetId
    let chain: Chain

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?

    init(
        balanceAccountAddress: AccountAddress,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        durationOperationFactory: StakingDurationOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        signer: SigningWrapperProtocol,
        chain: Chain,
        assetId: WalletAssetId
    ) {
        self.balanceAccountAddress = balanceAccountAddress
        self.singleValueProviderFactory = singleValueProviderFactory
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.durationOperationFactory = durationOperationFactory
        self.operationManager = operationManager
        self.signer = signer
        self.chain = chain
        self.assetId = assetId
    }

    // MARK: - SelectValidatorsConfirmInteractorInputProtocol

    func setup() {
        priceProvider = subscribeToPriceProvider(for: assetId)
        balanceProvider = subscribeToAccountInfoProvider(
            for: balanceAccountAddress,
            runtimeService: runtimeService
        )
        minBondProvider = subscribeToMinNominatorBondProvider(chain: chain, runtimeService: runtimeService)

        counterForNominatorsProvider = subscribeToCounterForNominatorsProvider(
            chain: chain,
            runtimeService: runtimeService
        )

        maxNominatorsCountProvider = subscribeToMaxNominatorsCountProvider(
            chain: chain,
            runtimeService: runtimeService
        )

        fetchStakingDuration(
            runtimeCodingService: runtimeService,
            operationFactory: durationOperationFactory,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveStakingDuration(result: result)
        }
    }

    func submitNomination(for _: Decimal, lastFee _: Decimal) {}

    func estimateFee() {}
}

extension SelectValidatorsConfirmInteractorBase: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePrice(result: result)
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chain _: Chain) {
        presenter.didReceiveMinBond(result: result)
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chain _: Chain) {
        presenter.didReceiveCounterForNominators(result: result)
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chain _: Chain) {
        presenter.didReceiveMaxNominatorsCount(result: result)
    }
}
