import Foundation
import RobinHood
import BigInt

protocol SelectValidatorsConfirmRelaychainExistingStrategyOutput: AnyObject {
    func didSetup()
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveMinBond(result: Result<BigUInt?, Error>)
    func didReceiveCounterForNominators(result: Result<UInt32?, Error>)
    func didReceiveMaxNominatorsCount(result: Result<UInt32?, Error>)
    func didReceiveStakingDuration(result: Result<StakingDuration, Error>)
    func didStartNomination()
    func didCompleteNomination(txHash: String)
    func didFailNomination(error: Error)
    func didReceive(paymentInfo: RuntimeDispatchInfo)
    func didReceive(feeError: Error)
}

final class SelectValidatorsConfirmRelaychainExistingStrategy: StakingDurationFetching {
    let balanceAccountId: AccountId
    let runtimeService: RuntimeCodingServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let durationOperationFactory: StakingDurationOperationFactoryProtocol
    let signer: SigningWrapperProtocol
    let operationManager: OperationManagerProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    let chainAsset: ChainAsset
    let output: SelectValidatorsConfirmRelaychainExistingStrategyOutput?

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
        chainAsset: ChainAsset,
        output: SelectValidatorsConfirmRelaychainExistingStrategyOutput?
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
        self.chainAsset = chainAsset
        self.output = output
    }
}

extension SelectValidatorsConfirmRelaychainExistingStrategy: SelectValidatorsConfirmStrategy {
    func estimateFee(closure: ExtrinsicBuilderClosure?) {
        guard let closure = closure else {
            return
        }

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.output?.didReceive(paymentInfo: info)
            case let .failure(error):
                self?.output?.didReceive(feeError: error)
            }
        }
    }

    func submitNomination(closure: ExtrinsicBuilderClosure?) {
//        guard !nomination.targets.isEmpty else {
//            output?.didFailNomination(error: SelectValidatorsConfirmError.extrinsicFailed)
//            return
//        }

        guard let closure = closure else {
            return
        }

        output?.didStartNomination()

        extrinsicService.submit(
            closure,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(txHash):
                self?.output?.didCompleteNomination(txHash: txHash)
            case let .failure(error):
                self?.output?.didFailNomination(error: error)
            }
        }
    }

    func setup() {
        output?.didSetup()

        accountInfoSubscriptionAdapter.subscribe(chain: chainAsset.chain, accountId: balanceAccountId, handler: self)

        minBondProvider = subscribeToMinNominatorBond(for: chainAsset.chain.chainId)

        counterForNominatorsProvider = subscribeToCounterForNominators(for: chainAsset.chain.chainId)

        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: chainAsset.chain.chainId)

        fetchStakingDuration(
            runtimeCodingService: runtimeService,
            operationFactory: durationOperationFactory,
            operationManager: operationManager
        ) { [weak self] result in
            self?.output?.didReceiveStakingDuration(result: result)
        }
    }
}

extension SelectValidatorsConfirmRelaychainExistingStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        output?.didReceiveMinBond(result: result)
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        output?.didReceiveCounterForNominators(result: result)
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        output?.didReceiveMaxNominatorsCount(result: result)
    }
}

extension SelectValidatorsConfirmRelaychainExistingStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        output?.didReceiveAccountInfo(result: result)
    }
}
