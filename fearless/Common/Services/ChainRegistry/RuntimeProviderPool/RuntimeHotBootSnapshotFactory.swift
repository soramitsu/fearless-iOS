import Foundation
import FearlessUtils
import RobinHood

protocol RuntimeHotBootSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for typesUsage: ChainModel.TypesUsage,
        dataHasher: StorageHasher,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?>
}

final class RuntimeHotBootSnapshotFactory {
    private let chainId: ChainModel.Id
    private let runtimeItem: RuntimeMetadataItem
    private let commonTypes: Data
    private let chainTypes: Data
    private let filesOperationFactory: RuntimeFilesOperationFactoryProtocol

    init(
        chainId: ChainModel.Id,
        runtimeItem: RuntimeMetadataItem,
        commonTypes: Data,
        chainTypes: Data,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    ) {
        self.chainId = chainId
        self.runtimeItem = runtimeItem
        self.commonTypes = commonTypes
        self.chainTypes = chainTypes
        self.filesOperationFactory = filesOperationFactory
    }

    private func createWrapperForCommonAndChainTypes(
        _ dataHasher: StorageHasher,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?> {
        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> { [weak self] in
            guard let strongSelf = self else { return nil }

            let decoder = try ScaleDecoder(data: strongSelf.runtimeItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                strongSelf.commonTypes,
                versioningData: strongSelf.chainTypes,
                runtimeMetadata: runtimeMetadata,
                usedRuntimePaths: usedRuntimePaths
            )

            return RuntimeSnapshot(
                localCommonHash: try dataHasher.hash(data: strongSelf.commonTypes).toHex(),
                localChainTypes: strongSelf.chainTypes,
                typeRegistryCatalog: catalog,
                specVersion: strongSelf.runtimeItem.version,
                txVersion: strongSelf.runtimeItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        return snapshotOperation
    }

    private func createWrapperForCommonTypes(
        _ dataHasher: StorageHasher,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?> {
        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> { [weak self] in
            guard let strongSelf = self else { return nil }

            let decoder = try ScaleDecoder(data: strongSelf.runtimeItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                strongSelf.commonTypes,
                runtimeMetadata: runtimeMetadata,
                usedRuntimePaths: usedRuntimePaths
            )

            return RuntimeSnapshot(
                localCommonHash: try dataHasher.hash(data: strongSelf.commonTypes).toHex(),
                localChainTypes: nil,
                typeRegistryCatalog: catalog,
                specVersion: strongSelf.runtimeItem.version,
                txVersion: strongSelf.runtimeItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        return snapshotOperation
    }

    private func createWrapperForChainTypes(
        _: StorageHasher,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?> {
        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> { [weak self] in
            guard let strongSelf = self else { return nil }

            let decoder = try ScaleDecoder(data: strongSelf.runtimeItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            // TODO: think about it
            let json: JSON = .dictionaryValue(["types": .dictionaryValue([:])])
            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                try JSONEncoder().encode(json),
                versioningData: strongSelf.chainTypes,
                runtimeMetadata: runtimeMetadata,
                usedRuntimePaths: usedRuntimePaths
            )

            return RuntimeSnapshot(
                localCommonHash: nil,
                localChainTypes: strongSelf.chainTypes,
                typeRegistryCatalog: catalog,
                specVersion: strongSelf.runtimeItem.version,
                txVersion: strongSelf.runtimeItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        return snapshotOperation
    }
}

extension RuntimeHotBootSnapshotFactory: RuntimeHotBootSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for typesUsage: ChainModel.TypesUsage,
        dataHasher: StorageHasher,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?> {
        switch typesUsage {
        case .onlyCommon:
            return createWrapperForCommonTypes(dataHasher, usedRuntimePaths: usedRuntimePaths)
        case .onlyOwn:
            return createWrapperForChainTypes(dataHasher, usedRuntimePaths: usedRuntimePaths)
        case .both:
            return createWrapperForCommonAndChainTypes(dataHasher, usedRuntimePaths: usedRuntimePaths)
        }
    }
}
