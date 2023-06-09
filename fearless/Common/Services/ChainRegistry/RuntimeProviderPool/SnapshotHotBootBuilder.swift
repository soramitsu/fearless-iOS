import Foundation
import RobinHood
import SSFUtils
import SSFModels

protocol SnapshotHotBootBuilderProtocol {
    func startHotBoot()
}

final class SnapshotHotBootBuilder: SnapshotHotBootBuilderProtocol {
    private let runtimeProviderPool: RuntimeProviderPoolProtocol
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    private let runtimeItemRepository: AnyDataProviderRepository<RuntimeMetadataItem>
    private let dataOperationFactory: DataOperationFactoryProtocol
    private let operationQueue: OperationQueue
    private let logger: Logger

    init(
        runtimeProviderPool: RuntimeProviderPoolProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        runtimeItemRepository: AnyDataProviderRepository<RuntimeMetadataItem>,
        dataOperationFactory: DataOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: Logger
    ) {
        self.runtimeProviderPool = runtimeProviderPool
        self.chainRepository = chainRepository
        self.filesOperationFactory = filesOperationFactory
        self.runtimeItemRepository = runtimeItemRepository
        self.dataOperationFactory = dataOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }

    // MARK: - Public

    func startHotBoot() {
        guard let chainsTypesUrl = ApplicationConfig.shared.chainsTypesURL else {
            assertionFailure()
            return
        }
        let chainsTypesFetchOperation = fetchChainsTypes(url: chainsTypesUrl)
        let runtimeItemsOperation = runtimeItemRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let chainModelOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        let mergeOperation = ClosureOperation<MergeOperationResult> {
            let chainsTypesResult = try chainsTypesFetchOperation.targetOperation.extractNoCancellableResultData()
            let runtimesResult = try runtimeItemsOperation.extractNoCancellableResultData()
            let chainModelResult = try chainModelOperation.extractNoCancellableResultData()

            return MergeOperationResult(
                chainsTypes: chainsTypesResult,
                runtimes: runtimesResult,
                chains: chainModelResult
            )
        }

        let dependencies = chainsTypesFetchOperation.allOperations
            + [runtimeItemsOperation]
            + [chainModelOperation]

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

    // MARK: - Private

    private func handleMergeOperation(result: SnapshotHotBootBuilder.MergeOperationResult) {
        let runtimeItemsMap = result.runtimes.reduce(
            into: [String: RuntimeMetadataItem]()
        ) { result, runtimeItem in
            result[runtimeItem.chain] = runtimeItem
        }

        guard
            let chainsTypes = result.chainsTypes,
            let chainsTypesJson = try? prepareVersionedJsons(from: chainsTypes)
        else {
            return
        }

        result.chains.forEach { chain in
            guard
                let runtimeItem = runtimeItemsMap[chain.chainId],
                let chainTypes = chainsTypesJson[chain.chainId]
            else {
                return
            }

            runtimeProviderPool.setupHotRuntimeProvider(
                for: chain,
                runtimeItem: runtimeItem,
                chainTypes: chainTypes
            )
        }
    }

    private func fetchChainsTypes(url: URL) -> CompoundOperationWrapper<Data> {
        let chainsTypesFetchOperation = filesOperationFactory.fetchChainsTypesOperation()
        let remoteChainsTypesOperation = dataOperationFactory.fetchData(from: url)

        remoteChainsTypesOperation.configurationBlock = { [weak self] in
            do {
                let localResult = try chainsTypesFetchOperation.targetOperation.extractNoCancellableResultData()
                if let data = localResult {
                    remoteChainsTypesOperation.result = .success(data)
                }
            } catch {
                self?.logger.error("\(error)")
            }
        }

        remoteChainsTypesOperation.addDependency(chainsTypesFetchOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: remoteChainsTypesOperation,
            dependencies: chainsTypesFetchOperation.allOperations
        )
    }

    private func prepareVersionedJsons(from data: Data) throws -> [String: Data] {
        if let localData = try? JSONDecoder().decode([String: Data].self, from: data) {
            return localData
        }
        guard let versionedDefinitionJsons = try JSONDecoder().decode(JSON.self, from: data).arrayValue else {
            throw ChainsTypesSyncError.missingData
        }

        return try versionedDefinitionJsons.reduce([String: Data]()) { partialResult, json in
            var partialResult = partialResult

            guard let chainId = json.chainId?.stringValue else {
                throw ChainsTypesSyncError.missingChainId
            }

            let data = try JSONEncoder().encode(json)

            partialResult[chainId] = data
            return partialResult
        }
    }

    private struct MergeOperationResult {
        let chainsTypes: Data?
        let runtimes: [RuntimeMetadataItem]
        let chains: [ChainModel]
    }
}
