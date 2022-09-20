import Foundation
import FearlessUtils
import RobinHood

protocol RuntimeHotBootSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for typesUsage: ChainModel.TypesUsage,
        dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?>
}

final class RuntimeHotBootSnapshotFactory {
    private let chainId: ChainModel.Id
    private let runtimeItem: RuntimeMetadataItem
    private let commonTypes: Data
    private let filesOperationFactory: RuntimeFilesOperationFactoryProtocol

    init(
        chainId: ChainModel.Id,
        runtimeItem: RuntimeMetadataItem,
        commonTypes: Data,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    ) {
        self.chainId = chainId
        self.runtimeItem = runtimeItem
        self.commonTypes = commonTypes
        self.filesOperationFactory = filesOperationFactory
    }

    private func createWrapperForCommonAndChainTypes(
        _ dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let chainTypesFetchOperation = filesOperationFactory.fetchChainTypesOperation(for: chainId)

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> { [weak self] in
            guard let strongSelf = self else { return nil }
            let chainTypes = try chainTypesFetchOperation.targetOperation.extractNoCancellableResultData()

            let decoder = try ScaleDecoder(data: strongSelf.runtimeItem.metadata)
            var runtimeMetadata: RuntimeMetadata
            if let resolver = strongSelf.runtimeItem.resolver {
                runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder, resolver: resolver)
            } else {
                runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)
            }

            guard let chainTypes = chainTypes else {
                return nil
            }

            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                strongSelf.commonTypes,
                versioningData: chainTypes,
                runtimeMetadata: runtimeMetadata
            )

            return RuntimeSnapshot(
                localCommonHash: try dataHasher.hash(data: strongSelf.commonTypes).toHex(),
                localChainHash: try dataHasher.hash(data: chainTypes).toHex(),
                typeRegistryCatalog: catalog,
                specVersion: strongSelf.runtimeItem.version,
                txVersion: strongSelf.runtimeItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        let dependencies = chainTypesFetchOperation.allOperations

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }

    private func createWrapperForCommonTypes(
        _ dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> { [weak self] in
            guard let strongSelf = self else { return nil }

            let decoder = try ScaleDecoder(data: strongSelf.runtimeItem.metadata)
            var runtimeMetadata: RuntimeMetadata
            if let resolver = strongSelf.runtimeItem.resolver {
                runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder, resolver: resolver)
            } else {
                runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)
            }

            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                strongSelf.commonTypes,
                runtimeMetadata: runtimeMetadata
            )

            return RuntimeSnapshot(
                localCommonHash: try dataHasher.hash(data: strongSelf.commonTypes).toHex(),
                localChainHash: nil,
                typeRegistryCatalog: catalog,
                specVersion: strongSelf.runtimeItem.version,
                txVersion: strongSelf.runtimeItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: [])
    }

    private func createWrapperForChainTypes(
        _ dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let chainTypesFetchOperation = filesOperationFactory.fetchChainTypesOperation(for: chainId)

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> { [weak self] in
            guard let strongSelf = self else { return nil }
            let ownTypes = try chainTypesFetchOperation.targetOperation.extractNoCancellableResultData()

            let decoder = try ScaleDecoder(data: strongSelf.runtimeItem.metadata)
            var runtimeMetadata: RuntimeMetadata
            if let resolver = strongSelf.runtimeItem.resolver {
                runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder, resolver: resolver)
            } else {
                runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)
            }

            guard let ownTypes = ownTypes else {
                return nil
            }

            // TODO: think about it
            let json: JSON = .dictionaryValue(["types": .dictionaryValue([:])])
            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                try JSONEncoder().encode(json),
                versioningData: ownTypes,
                runtimeMetadata: runtimeMetadata
            )

            return RuntimeSnapshot(
                localCommonHash: nil,
                localChainHash: try dataHasher.hash(data: ownTypes).toHex(),
                typeRegistryCatalog: catalog,
                specVersion: strongSelf.runtimeItem.version,
                txVersion: strongSelf.runtimeItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        let dependencies = chainTypesFetchOperation.allOperations

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }
}

extension RuntimeHotBootSnapshotFactory: RuntimeHotBootSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for typesUsage: ChainModel.TypesUsage,
        dataHasher: StorageHasher
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        switch typesUsage {
        case .onlyCommon:
            return createWrapperForCommonTypes(dataHasher)
        case .onlyOwn:
            return createWrapperForChainTypes(dataHasher)
        case .both:
            return createWrapperForCommonAndChainTypes(dataHasher)
        }
    }
}
