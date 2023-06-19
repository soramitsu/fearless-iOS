import Foundation
import SSFUtils
import RobinHood
import SSFModels

protocol RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        chainTypes: Data,
        chainMetadata: RuntimeMetadataItem,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?>
}

final class RuntimeSnapshotFactory {
    private let chainId: ChainModel.Id
    private let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    private let repository: AnyDataProviderRepository<RuntimeMetadataItem>

    init(
        chainId: ChainModel.Id,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        repository: AnyDataProviderRepository<RuntimeMetadataItem>
    ) {
        self.chainId = chainId
        self.filesOperationFactory = filesOperationFactory
        self.repository = repository
    }

    private func createWrapperForChainTypes(
        ownTypes: Data,
        runtimeMetadataItem: RuntimeMetadataItem,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?> {
        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            // TODO: think about it
            let json: JSON = .dictionaryValue(["types": .dictionaryValue([:])])
            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                try JSONEncoder().encode(json),
                versioningData: ownTypes,
                runtimeMetadata: runtimeMetadata,
                usedRuntimePaths: usedRuntimePaths
            )

            return RuntimeSnapshot(
                localCommonHash: nil,
                localChainTypes: ownTypes,
                typeRegistryCatalog: catalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        return snapshotOperation
    }
}

extension RuntimeSnapshotFactory: RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        chainTypes: Data,
        chainMetadata: RuntimeMetadataItem,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?> {
        createWrapperForChainTypes(
            ownTypes: chainTypes,
            runtimeMetadataItem: chainMetadata,
            usedRuntimePaths: usedRuntimePaths
        )
    }
}
