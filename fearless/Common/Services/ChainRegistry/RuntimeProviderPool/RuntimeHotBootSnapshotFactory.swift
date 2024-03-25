import Foundation
import SSFUtils
import RobinHood
import SSFModels

protocol RuntimeHotBootSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        chainTypes: Data?
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
        chainTypes: Data?
    ) -> ClosureOperation<RuntimeSnapshot?> {
        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> { [weak self] in
            guard let strongSelf = self else { return nil }

            let decoder = try ScaleDecoder(data: strongSelf.runtimeItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            var definitionJson: JSON?
            if let data = chainTypes {
                let jsonDecoder = JSONDecoder()
                let json = try jsonDecoder.decode(JSON.self, from: data)
                definitionJson = json.types
            }

            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                definitionJson: definitionJson,
                versioningData: chainTypes,
                runtimeMetadata: runtimeMetadata
            )

            return RuntimeSnapshot(
                localCommonHash: nil,
                localChainTypes: chainTypes,
                typeRegistryCatalog: catalog,
                specVersion: strongSelf.runtimeItem.version,
                txVersion: strongSelf.runtimeItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        return snapshotOperation
    }
}
