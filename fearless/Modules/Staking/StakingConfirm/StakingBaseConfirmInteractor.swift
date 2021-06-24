import Foundation
import RobinHood
import BigInt

class StakingBaseConfirmInteractor: StakingConfirmInteractorInputProtocol {
    weak var presenter: StakingConfirmInteractorOutputProtocol!

    let balanceAccountAddress: AccountAddress
    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let signer: SigningWrapperProtocol
    let operationManager: OperationManagerProtocol
    let assetId: WalletAssetId
    let chain: Chain

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?
    private var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?

    init(
        balanceAccountAddress: AccountAddress,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        signer: SigningWrapperProtocol,
        chain: Chain,
        assetId: WalletAssetId
    ) {
        self.balanceAccountAddress = balanceAccountAddress
        self.singleValueProviderFactory = singleValueProviderFactory
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.signer = signer
        self.chain = chain
        self.assetId = assetId
    }

    // MARK: StakingConfirmInteractorInputProtocol

    func setup() {
        priceProvider = subscribeToPriceProvider(for: assetId)
        balanceProvider = subscribeToAccountInfoProvider(
            for: balanceAccountAddress,
            runtimeService: runtimeService
        )
        electionStatusProvider = subscribeToElectionStatusProvider(chain: chain, runtimeService: runtimeService)
        minBondProvider = subscribeToMinNominatorBondProvider(chain: chain, runtimeService: runtimeService)

        counterForNominatorsProvider = subscribeToCounterForNominatorsProvider(
            chain: chain,
            runtimeService: runtimeService
        )

        maxNominatorsCountProvider = subscribeToMaxNominatorsCountProvider(
            chain: chain,
            runtimeService: runtimeService
        )
    }

    func submitNomination(for _: Decimal, lastFee _: Decimal) {}

    func estimateFee() {}
}

extension StakingBaseConfirmInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
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

    func handleElectionStatus(result: Result<ElectionStatus?, Error>, chain _: Chain) {
        presenter.didReceiveElectionStatus(result: result)
    }
}
