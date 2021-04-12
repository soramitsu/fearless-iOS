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
    let logger: LoggerProtocol?

    let syncQueue = DispatchQueue(
        label: "jp.co.fearless.payout.\(UUID().uuidString)",
        qos: .userInitiated
    )

    private(set) var activeEra: UInt32?
    private(set) var chain: Chain?
    private var isActive: Bool = false

    init(
        selectedAccountAddress: String,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        providerFactory: SubstrateDataProviderFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedAccountAddress = selectedAccountAddress
        self.runtimeCodingService = runtimeCodingService
        self.engine = engine
        self.operationManager = operationManager
        self.providerFactory = providerFactory
        self.logger = logger
    }

    func fetchPayoutRewards(completion: @escaping PayoutRewardsClosure) {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        do {
            let mergeOperationWrapper = try createFetchFirstStepsOperation(
                engine: engine,
                codingFactoryOperation: codingFactoryOperation
            )

            let totalRewards = try createFetchTotalRewardOperation(
                dependingOn: mergeOperationWrapper.targetOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation
            )
            totalRewards.allOperations.forEach { $0.addDependency(mergeOperationWrapper.targetOperation) }

            let operations = [codingFactoryOperation]
                + mergeOperationWrapper.allOperations
                + totalRewards.allOperations

            totalRewards.targetOperation.completionBlock = {
                do {
                    let res = try totalRewards.targetOperation.extractNoCancellableResultData()
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
