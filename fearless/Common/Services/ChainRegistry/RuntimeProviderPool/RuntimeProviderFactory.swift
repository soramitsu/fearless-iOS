import Foundation
import RobinHood

protocol RuntimeProviderFactoryProtocol {
    func createRuntimeProvider(
        for chain: ChainModel,
        usedRuntimePaths: [String: [String]]
    ) -> RuntimeProviderProtocol
    func createHotRuntimeProvider(
        for chain: ChainModel,
        runtimeItem: RuntimeMetadataItem,
        commonTypes: Data,
        chainTypes: Data,
        usedRuntimePaths: [String: [String]]
    ) -> RuntimeProviderProtocol
}

final class RuntimeProviderFactory {
    let fileOperationFactory: RuntimeFilesOperationFactoryProtocol
    let repository: AnyDataProviderRepository<RuntimeMetadataItem>
    let dataOperationFactory: DataOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?

    init(
        fileOperationFactory: RuntimeFilesOperationFactoryProtocol,
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        dataOperationFactory: DataOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.fileOperationFactory = fileOperationFactory
        self.repository = repository
        self.dataOperationFactory = dataOperationFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension RuntimeProviderFactory: RuntimeProviderFactoryProtocol {
    func createRuntimeProvider(
        for chain: ChainModel,
        usedRuntimePaths: [String: [String]]
    ) -> RuntimeProviderProtocol {
        let snapshotOperationFactory = RuntimeSnapshotFactory(
            chainId: chain.chainId,
            filesOperationFactory: fileOperationFactory,
            repository: repository
        )

        return RuntimeProvider(
            chainModel: chain,
            snapshotOperationFactory: snapshotOperationFactory,
            snapshotHotOperationFactory: nil,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger,
            repository: repository,
            usedRuntimePaths: usedRuntimePaths,
            chainMetadata: nil
        )
    }

    func createHotRuntimeProvider(
        for chain: ChainModel,
        runtimeItem: RuntimeMetadataItem,
        commonTypes: Data,
        chainTypes: Data,
        usedRuntimePaths: [String: [String]]
    ) -> RuntimeProviderProtocol {
        let snapshotOperationFactory = RuntimeSnapshotFactory(
            chainId: chain.chainId,
            filesOperationFactory: fileOperationFactory,
            repository: repository
        )

        let snapshotHotOperationFactory = RuntimeHotBootSnapshotFactory(
            chainId: chain.chainId,
            runtimeItem: runtimeItem,
            commonTypes: commonTypes,
            chainTypes: chainTypes,
            filesOperationFactory: fileOperationFactory
        )

        return RuntimeProvider(
            chainModel: chain,
            snapshotOperationFactory: snapshotOperationFactory,
            snapshotHotOperationFactory: snapshotHotOperationFactory,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger,
            repository: repository,
            usedRuntimePaths: usedRuntimePaths,
            chainMetadata: runtimeItem
        )
    }
}
