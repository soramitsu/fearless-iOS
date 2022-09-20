import Foundation
import RobinHood

protocol SnapshotHotBootBuilderProtocol {
    func startHotBoot()
}

final class SnapshotHotBootBuilder: SnapshotHotBootBuilderProtocol {
    private let runtimeProviderPool: RuntimeProviderPoolProtocol
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    private let runtimeItemRepository: AnyDataProviderRepository<RuntimeMetadataItem>
    private let operationQueue: OperationQueue
    private let logger: Logger

    init(
        runtimeProviderPool: RuntimeProviderPoolProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        runtimeItemRepository: AnyDataProviderRepository<RuntimeMetadataItem>,
        operationQueue: OperationQueue,
        logger: Logger
    ) {
        self.runtimeProviderPool = runtimeProviderPool
        self.chainRepository = chainRepository
        self.filesOperationFactory = filesOperationFactory
        self.runtimeItemRepository = runtimeItemRepository
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func startHotBoot() {
        let baseTypesFetchOperation = filesOperationFactory.fetchCommonTypesOperation()
        let runtimeItemsOperation = runtimeItemRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let chainModelOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        let mergeOperation = ClosureOperation<MergeOperationResult> {
            let commonTypesResult = try baseTypesFetchOperation.targetOperation.extractNoCancellableResultData()
            let runtimesResult = try runtimeItemsOperation.extractNoCancellableResultData()
            let chainModelResult = try chainModelOperation.extractNoCancellableResultData()

            return MergeOperationResult(
                commonTypes: commonTypesResult,
                runtimes: runtimesResult,
                chains: chainModelResult
            )
        }

        let dependencies = baseTypesFetchOperation.allOperations + [runtimeItemsOperation] + [chainModelOperation]

        dependencies.forEach { mergeOperation.addDependency($0) }

        mergeOperation.completionBlock = { [weak self] in
            do {
                let result = try mergeOperation.extractNoCancellableResultData()
                self?.handleMergeOperation(result: result)
            } catch {
                self?.logger.error(error.localizedDescription)
            }
        }

        let compoundOperation = CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)

        operationQueue.addOperations(compoundOperation.allOperations, waitUntilFinished: false)
    }

    private func handleMergeOperation(result: SnapshotHotBootBuilder.MergeOperationResult) {
        let runtimeItemsMap = result.runtimes.reduce(
            into: [String: RuntimeMetadataItem]()
        ) { result, runtimeItem in
            result[runtimeItem.chain] = runtimeItem
        }

        result.chains.forEach { chain in
            guard let commonTypes = result.commonTypes,
                  let runtimeItem = runtimeItemsMap[chain.chainId] else {
                return
            }
            runtimeProviderPool.setupHotRuntimeProvider(
                for: chain,
                runtimeItem: runtimeItem,
                commonTypes: commonTypes
            )
        }
    }

    private struct MergeOperationResult {
        let commonTypes: Data?
        let runtimes: [RuntimeMetadataItem]
        let chains: [ChainModel]
    }
}
