import Foundation
import RobinHood
import BigInt
import SSFModels

protocol SelectValidatorsConfirmRelaychainExistingStrategyOutput: SelectValidatorsConfirmStrategyOutput {
    func didSetup()
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
    private let balanceAccountId: AccountId
    private let runtimeService: RuntimeCodingServiceProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let durationOperationFactory: StakingDurationOperationFactoryProtocol
    private let signer: SigningWrapperProtocol
    private let operationManager: OperationManagerProtocol
    private let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private(set) var stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private let chainAsset: ChainAsset
    private let output: SelectValidatorsConfirmRelaychainExistingStrategyOutput?
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<[PriceData]>?
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?

    init(
        balanceAccountId: AccountId,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        durationOperationFactory: StakingDurationOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        signer: SigningWrapperProtocol,
        chainAsset: ChainAsset,
        output: SelectValidatorsConfirmRelaychainExistingStrategyOutput?,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    ) {
        self.balanceAccountId = balanceAccountId
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.durationOperationFactory = durationOperationFactory
        self.operationManager = operationManager
        self.signer = signer
        self.chainAsset = chainAsset
        self.output = output
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
    }
}

extension SelectValidatorsConfirmRelaychainExistingStrategy: SelectValidatorsConfirmStrategy {
    func subscribeToBalance() {
        accountInfoSubscriptionAdapter.subscribe(
            chainAsset: chainAsset,
            accountId: balanceAccountId,
            handler: self
        )
    }

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

        output?.didSetup()
    }
}

extension SelectValidatorsConfirmRelaychainExistingStrategy:
    RelaychainStakingLocalStorageSubscriber,
    RelaychainStakingLocalSubscriptionHandler,
    AccountInfoSubscriptionAdapterHandler {
    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        output?.didReceiveMinBond(result: result)
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        output?.didReceiveCounterForNominators(result: result)
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        output?.didReceiveMaxNominatorsCount(result: result)
    }

    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset _: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result)
    }
}
