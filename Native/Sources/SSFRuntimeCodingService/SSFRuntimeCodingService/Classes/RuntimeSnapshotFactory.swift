import Foundation
import RobinHood
import SSFModels
import SSFUtils

public protocol RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        chainTypes: Data,
        chainMetadata: RuntimeMetadataItemProtocol,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?>
}

public final class RuntimeSnapshotFactory: RuntimeSnapshotFactoryProtocol {
    public func createRuntimeSnapshotWrapper(
        chainTypes: Data,
        chainMetadata: RuntimeMetadataItemProtocol,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?> {
        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let decoder = try ScaleDecoder(data: chainMetadata.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            // TODO: think about it
            let json: JSON = .dictionaryValue(["types": .dictionaryValue([:])])
            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                JSONEncoder().encode(json),
                versioningData: chainTypes,
                runtimeMetadata: runtimeMetadata,
                usedRuntimePaths: usedRuntimePaths
            )

            return RuntimeSnapshot(
                typeRegistryCatalog: catalog,
                specVersion: chainMetadata.version,
                txVersion: chainMetadata.txVersion,
                metadata: runtimeMetadata
            )
        }

        return snapshotOperation
    }
}
