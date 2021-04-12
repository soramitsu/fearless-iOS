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

        let currentEra = createCurrentEraWrapper(
            engine: engine,
            codingFactory: { try codingFactoryOperation.extractNoCancellableResultData() }
        )
        currentEra.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let activeEra = createActiveEraWrapper(
            engine: engine,
            codingFactory: { try codingFactoryOperation.extractNoCancellableResultData() }
        )
        activeEra.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let historyDepth = createHistoryDepthWrapper(
            engine: engine,
            codingFactory: { try codingFactoryOperation.extractNoCancellableResultData() }
        )
        historyDepth.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        // BaseOperation<Strufwith3propterties>
        let mergeOperation = ClosureOperation {
            let currentEra = try currentEra.targetOperation.extractNoCancellableResultData()
                .first?.value?.value
            let activeEra = try activeEra.targetOperation.extractNoCancellableResultData()
                .first?.value
            let historyDepth = try historyDepth.targetOperation.extractNoCancellableResultData()
                .first?.value?.value
            print(currentEra)
            completion(.success(currentEra!.description))
        }
        mergeOperation.addDependency(currentEra.targetOperation)
        mergeOperation.addDependency(activeEra.targetOperation)
        mergeOperation.addDependency(historyDepth.targetOperation)

        let operations = [codingFactoryOperation, mergeOperation]
            + activeEra.allOperations
            + currentEra.allOperations
            + historyDepth.allOperations
        operationManager.enqueue(operations: operations, in: .transient)
    }

    func fetchHistoryDepth() -> UInt32 {
        0
    }

    private func createCurrentEraWrapper(
        engine: JSONRPCEngine,
        codingFactory: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> {
        let keyFactory = StorageKeyFactory()
        let requestFactory = StorageRequestFactory(remoteFactory: keyFactory)

        let queryWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            requestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.currentEra()] },
                factory: codingFactory,
                storagePath: .currentEra
            )
        return queryWrapper
    }

    private func createActiveEraWrapper(
        engine: JSONRPCEngine,
        codingFactory: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[StorageResponse<ActiveEraInfo>]> {
        let keyFactory = StorageKeyFactory()
        let requestFactory = StorageRequestFactory(remoteFactory: keyFactory)

        return requestFactory.queryItems(
            engine: engine,
            keys: { [try keyFactory.activeEra()] },
            factory: codingFactory,
            storagePath: .activeEra
        )
    }

    private func createHistoryDepthWrapper(
        engine: JSONRPCEngine,
        codingFactory: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> {
        let keyFactory = StorageKeyFactory()
        let requestFactory = StorageRequestFactory(remoteFactory: keyFactory)

        return requestFactory.queryItems(
            engine: engine,
            keys: { [try keyFactory.historyDepth()] },
            factory: codingFactory,
            storagePath: .historyDepth
        )
    }
}

struct PayoutCalculateFirstStepResult {
    let currentEra: UInt32
    let activeEra: UInt32
    let historyDepth: UInt32
}
