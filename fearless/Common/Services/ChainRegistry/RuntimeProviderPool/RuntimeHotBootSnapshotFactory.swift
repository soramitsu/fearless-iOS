import Foundation
import SSFUtils
import RobinHood
import SSFModels
import SSFRuntimeCodingService

protocol RuntimeHotBootSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        usedRuntimePaths: [String: [String]],
        chainTypes: Data
    ) -> ClosureOperation<RuntimeSnapshot?>
}

final class RuntimeHotBootSnapshotFactory: RuntimeHotBootSnapshotFactoryProtocol {
    private let chainId: ChainModel.Id
    private let runtimeItem: RuntimeMetadataItem
    private let filesOperationFactory: RuntimeFilesOperationFactoryProtocol

    init(
        chainId: ChainModel.Id,
        runtimeItem: RuntimeMetadataItem,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    ) {
        self.chainId = chainId
        self.runtimeItem = runtimeItem
        self.filesOperationFactory = filesOperationFactory
    }

    func createRuntimeSnapshotWrapper(
        usedRuntimePaths: [String: [String]],
        chainTypes: Data
    ) -> ClosureOperation<RuntimeSnapshot?> {
        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> { [weak self] in
            guard let strongSelf = self else { return nil }

            let decoder = try ScaleDecoder(data: strongSelf.runtimeItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            // TODO: think about it
            let json: JSON = .dictionaryValue(["types": .dictionaryValue([:])])
            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                try JSONEncoder().encode(json),
                versioningData: chainTypes,
                runtimeMetadata: runtimeMetadata,
                usedRuntimePaths: usedRuntimePaths
            )

            return RuntimeSnapshot(
                typeRegistryCatalog: catalog,
                specVersion: strongSelf.runtimeItem.version,
                txVersion: strongSelf.runtimeItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        return snapshotOperation
    }
}
