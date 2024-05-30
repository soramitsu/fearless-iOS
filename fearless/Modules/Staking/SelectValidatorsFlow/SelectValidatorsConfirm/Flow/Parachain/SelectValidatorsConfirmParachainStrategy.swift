import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService

protocol SelectValidatorsConfirmParachainStrategyOutput: SelectValidatorsConfirmStrategyOutput {
    func didReceiveAtStake(snapshot: ParachainStakingCollatorSnapshot?)
    func didReceiveDelegatorState(state: ParachainStakingDelegatorState?)
    func didReceiveNetworkStakingInfo(info: NetworkStakingInfo)
    func didReceive(error: Error)
    func didStartNomination()
    func didCompleteNomination(txHash: String)
    func didFailNomination(error: Error)
    func didReceive(paymentInfo: RuntimeDispatchInfo)
    func didReceiveFeeError(_ feeError: Error)
    func didSetup()
}

final class SelectValidatorsConfirmParachainStrategy {
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let collatorAccountId: AccountId
    private let balanceAccountId: AccountId
    private let runtimeService: RuntimeCodingServiceProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let signer: SigningWrapperProtocol
    private let operationManager: OperationManagerProtocol
    private let chainAsset: ChainAsset
    private let output: SelectValidatorsConfirmParachainStrategyOutput?
    private let collatorOperationFactory: ParachainCollatorOperationFactory
    private let eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    private let eraValidatorService: EraValidatorServiceProtocol

    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        collatorAccountId: AccountId,
        balanceAccountId: AccountId,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        operationManager: OperationManagerProtocol,
        chainAsset: ChainAsset,
        output: SelectValidatorsConfirmParachainStrategyOutput?,
        collatorOperationFactory: ParachainCollatorOperationFactory,
        eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.collatorAccountId = collatorAccountId
        self.balanceAccountId = balanceAccountId
        self.runtimeService = runtimeService
        self.extrinsicService = extrinsicService
        self.signer = signer
        self.operationManager = operationManager
        self.chainAsset = chainAsset
        self.output = output
        self.collatorOperationFactory = collatorOperationFactory
        self.eraInfoOperationFactory = eraInfoOperationFactory
        self.eraValidatorService = eraValidatorService
    }
}

extension SelectValidatorsConfirmParachainStrategy: SelectValidatorsConfirmStrategy {
    func subscribeToBalance() {
        accountInfoSubscriptionAdapter.subscribe(
            chainAsset: chainAsset,
            accountId: balanceAccountId,
            handler: self
        )
    }

    func setup() {
        fetchDelegatorState()
        provideNetworkStakingInfo()
        fetchAtStake()

        output?.didSetup()
    }

    func fetchAtStake() {
        let atStakeOperation = collatorOperationFactory.collatorAtStake(collatorAccountId: collatorAccountId)

        atStakeOperation.targetOperation.completionBlock = { [weak self] in
            guard let strongSelf = self else {
                return
            }

            DispatchQueue.main.async {
                do {
                    let address = try AddressFactory.address(
                        for: strongSelf.collatorAccountId,
                        chainFormat: strongSelf.chainAsset.chain.chainFormat
                    )

                    let response = try atStakeOperation.targetOperation.extractNoCancellableResultData()
                    let atStake = response?[address]

                    strongSelf.output?.didReceiveAtStake(snapshot: atStake)
                } catch {
                    strongSelf.output?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: atStakeOperation.allOperations, in: .transient)
    }

    func fetchDelegatorState() {
        let balanceAccountId = balanceAccountId
        let delegatorStateOperation = collatorOperationFactory.delegatorState {
            [balanceAccountId]
        }

        delegatorStateOperation.targetOperation.completionBlock = { [weak self] in
            guard let strongSelf = self else {
                return
            }

            DispatchQueue.main.async {
                do {
                    let address = try AddressFactory.address(
                        for: strongSelf.balanceAccountId,
                        chainFormat: strongSelf.chainAsset.chain.chainFormat
                    )

                    let response = try delegatorStateOperation.targetOperation.extractNoCancellableResultData()
                    let delegatorState = response?[address]

                    strongSelf.output?.didReceiveDelegatorState(state: delegatorState)
                } catch {
                    strongSelf.output?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: delegatorStateOperation.allOperations, in: .transient)
    }

    func provideNetworkStakingInfo() {
        let wrapper = eraInfoOperationFactory.networkStakingOperation(
            for: eraValidatorService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceiveNetworkStakingInfo(info: info)
                } catch {
                    self?.output?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
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
                self?.output?.didReceiveFeeError(error)
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
}

extension SelectValidatorsConfirmParachainStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset _: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result)
    }
}
