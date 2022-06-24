import Foundation
import RobinHood

protocol SelectValidatorsConfirmParachainStrategyOutput: AnyObject {
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
    let collatorAccountId: AccountId
    let balanceAccountId: AccountId
    let runtimeService: RuntimeCodingServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let signer: SigningWrapperProtocol
    let operationManager: OperationManagerProtocol
    let chainAsset: ChainAsset
    let output: SelectValidatorsConfirmParachainStrategyOutput?
    let collatorOperationFactory: ParachainCollatorOperationFactory
    let eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol

    init(
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
                    print("error: ", error)
                }
            }
        }

        operationManager.enqueue(operations: atStakeOperation.allOperations, in: .transient)
    }

    func fetchDelegatorState() {
        let delegatorStateOperation = collatorOperationFactory.delegatorState { [unowned self] in
            [self.balanceAccountId]
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
                    print("error: ", error)
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

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
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
