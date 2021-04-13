import Foundation
import FearlessUtils
import RobinHood

final class PayoutRewardsService: PayoutRewardsServiceProtocol {
    func update(to _: Chain) {}

    let selectedAccountAddress: String
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let engine: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let providerFactory: SubstrateDataProviderFactoryProtocol
    let subscanOperationFactory: SubscanOperationFactoryProtocol
    let logger: LoggerProtocol?

    let syncQueue = DispatchQueue(
        label: "jp.co.fearless.payout.\(UUID().uuidString)",
        qos: .userInitiated
    )

    private(set) var activeEra: UInt32?
    private let chain: Chain
    private var isActive: Bool = false

    init(
        selectedAccountAddress: String,
        chain: Chain,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        providerFactory: SubstrateDataProviderFactoryProtocol,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedAccountAddress = selectedAccountAddress
        self.chain = chain
        self.runtimeCodingService = runtimeCodingService
        self.engine = engine
        self.operationManager = operationManager
        self.providerFactory = providerFactory
        self.subscanOperationFactory = subscanOperationFactory
        self.logger = logger
    }

    func fetchPayoutRewards(completion: @escaping PayoutRewardsClosure) {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        do {
            let steps1to3OperationWrapper = try createSteps1To3OperationWrapper(
                engine: engine,
                codingFactoryOperation: codingFactoryOperation
            )

            let steps4And5OperationWrapper = try createSteps4And5OperationWrapper(
                dependingOn: steps1to3OperationWrapper.targetOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation
            )
            steps4And5OperationWrapper.allOperations
                .forEach { $0.addDependency(steps1to3OperationWrapper.targetOperation) }

            let nominationHistoryStep6Controllers = try createControllersStep6Operation(
                nominatorAccount: selectedAccountAddress,
                chain: chain,
                subscanOperationFactory: subscanOperationFactory
            )

            nominationHistoryStep6Controllers.targetOperation.completionBlock = {
                do {
                    let controllersSet = try nominationHistoryStep6Controllers
                        .targetOperation.extractNoCancellableResultData()

                    let validatorsWrapper = try self.createFindValidatorsOperation(
                        controllers: controllersSet,
                        chain: self.chain,
                        subscanOperationFactory: self.subscanOperationFactory
                    )

                    let controllersWrapper = try self.createControllersByValidatorStashOperation(
                        dependingOn: validatorsWrapper.targetOperation,
                        chain: self.chain,
                        engine: self.engine,
                        codingFactoryOperation: codingFactoryOperation
                    )
                    controllersWrapper.allOperations
                        .forEach { $0.addDependency(validatorsWrapper.targetOperation) }

                    let ledgerInfos = try self.createLedgerInfoOperation(
                        dependingOn: controllersWrapper.targetOperation,
                        engine: self.engine,
                        codingFactoryOperation: codingFactoryOperation
                    )
                    ledgerInfos.allOperations
                        .forEach { $0.addDependency(controllersWrapper.targetOperation) }

                    ledgerInfos.targetOperation.completionBlock = {
                        // swiftlint:disable force_try
                        let res = try! ledgerInfos
                            .targetOperation.extractNoCancellableResultData()
                        print(res)
                    }

                    self.operationManager.enqueue(
                        operations: validatorsWrapper.allOperations + controllersWrapper.allOperations + ledgerInfos.allOperations,
                        in: .transient
                    )
                } catch {
                    completion(.failure(error))
                }
            }

            let operations = [codingFactoryOperation]
                + steps1to3OperationWrapper.allOperations
                + steps4And5OperationWrapper.allOperations
                + nominationHistoryStep6Controllers.allOperations

            steps4And5OperationWrapper.targetOperation.completionBlock = {
                do {
                    let res = try steps4And5OperationWrapper.targetOperation.extractNoCancellableResultData()
                    print(res)
                } catch {
                    completion(.failure(error))
                }
            }

            operationManager.enqueue(operations: operations, in: .transient)
        } catch {
            logger?.debug(error.localizedDescription)
            completion(.failure(error))
        }
    }
}
