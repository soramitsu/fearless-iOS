import Foundation
import SSFUtils
import RobinHood
import SSFModels
import SSFRuntimeCodingService

protocol PolkaswapOperationFactoryProtocol {
    func createIsPathAvailableOperation(
        dexId: UInt32,
        from fromAssetId: String,
        to toAssetId: String
    ) -> JSONRPCOperation<[PolkaswapJSON], Bool>
    func createGetAvailableMarketAlgorithmsOperation(
        dexId: UInt32,
        from fromAssetId: String,
        to toAssetId: String
    ) -> JSONRPCOperation<[PolkaswapJSON], [String]>
    func createIsPathAvalableAndMarketCompoundOperation(
        dexId: UInt32,
        from fromAssetId: String,
        to toAssetId: String
    ) -> CompoundOperationWrapper<(isAvailable: Bool, markets: [String])>
    func createPolkaswapQuoteOperation(
        dexId: UInt32,
        params: PolkaswapQuoteParams
    ) -> JSONRPCOperation<[PolkaswapJSON], SwapValues>
    func createDexInfosOperation() -> CompoundOperationWrapper<[UInt32]>
}

final class PolkaswapOperationFactory: PolkaswapOperationFactoryProtocol {
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let chainId: ChainModel.Id
    init(
        storageRequestFactory: StorageRequestFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        chainId: ChainModel.Id
    ) {
        self.storageRequestFactory = storageRequestFactory
        self.chainRegistry = chainRegistry
        self.chainId = chainId
    }

    func createIsPathAvailableOperation(
        dexId: UInt32,
        from fromAssetId: String,
        to toAssetId: String
    ) -> JSONRPCOperation<[PolkaswapJSON], Bool> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return JSONRPCOperation.failureOperation(ChainRegistryError.connectionUnavailable)
        }

        let parameters: [PolkaswapJSON] = [
            PolkaswapJSON(dexId),
            PolkaswapJSON(fromAssetId),
            PolkaswapJSON(toAssetId)
        ]

        return JSONRPCOperation<[PolkaswapJSON], Bool>(
            engine: connection,
            method: RPCMethod.checkIsSwapPossible,
            parameters: parameters
        )
    }

    func createGetAvailableMarketAlgorithmsOperation(
        dexId: UInt32,
        from fromAssetId: String,
        to toAssetId: String
    ) -> JSONRPCOperation<[PolkaswapJSON], [String]> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return JSONRPCOperation<[PolkaswapJSON], [String]>.failureOperation(ChainRegistryError.connectionUnavailable)
        }

        let parameters: [PolkaswapJSON] = [
            PolkaswapJSON(dexId),
            PolkaswapJSON(fromAssetId),
            PolkaswapJSON(toAssetId)
        ]

        return JSONRPCOperation<[PolkaswapJSON], [String]>(
            engine: connection,
            method: RPCMethod.availableMarketAlgorithms,
            parameters: parameters
        )
    }

    func createIsPathAvalableAndMarketCompoundOperation(
        dexId: UInt32,
        from fromAssetId: String,
        to toAssetId: String
    ) -> CompoundOperationWrapper<(isAvailable: Bool, markets: [String])> {
        let fetchIsPathAvailableOperation = createIsPathAvailableOperation(
            dexId: dexId,
            from: fromAssetId,
            to: toAssetId
        )

        let fetchMarketsOperation = createGetAvailableMarketAlgorithmsOperation(
            dexId: dexId,
            from: fromAssetId,
            to: toAssetId
        )

        let mergeOperation: BaseOperation<(
            isAvailable: Bool,
            markets: [String]
        )> = ClosureOperation {
            let isAvailable = try fetchIsPathAvailableOperation.extractNoCancellableResultData()
            let markets = try fetchMarketsOperation.extractNoCancellableResultData()

            return (isAvailable: isAvailable, markets: markets)
        }

        mergeOperation.addDependency(fetchIsPathAvailableOperation)
        mergeOperation.addDependency(fetchMarketsOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [
                fetchIsPathAvailableOperation,
                fetchMarketsOperation
            ]
        )
    }

    func createPolkaswapQuoteOperation(
        dexId: UInt32,
        params: PolkaswapQuoteParams
    ) -> JSONRPCOperation<[PolkaswapJSON], SwapValues> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return JSONRPCOperation.failureOperation(ChainRegistryError.connectionUnavailable)
        }

        let paramsArray: [PolkaswapJSON] = [
            PolkaswapJSON(dexId),
            PolkaswapJSON(params.fromAssetId),
            PolkaswapJSON(params.toAssetId),
            PolkaswapJSON(params.amount),
            PolkaswapJSON(params.swapVariant.rawValue),
            PolkaswapJSON(params.liquiditySources),
            PolkaswapJSON(params.filterMode.code)
        ]

        return JSONRPCOperation<[PolkaswapJSON], SwapValues>(
            engine: connection,
            method: RPCMethod.recalculateSwapValues,
            parameters: paramsArray
        )
    }

    func createDexInfosOperation() -> CompoundOperationWrapper<[UInt32]> {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let dexInfosOperation = createDexInfosOperation(dependingOn: runtimeOperation)

        let mapDexInfosOperation = AwaitOperation<[UInt32]>(closure: {
            try await dexInfosOperation.targetOperation.extractNoCancellableResultData().asyncMap { storageResponse in
                let extractor = StorageKeyDataExtractor(runtimeService: runtimeService)
                let id: String = try await extractor.extractKey(
                    storageKey: storageResponse.key,
                    storagePath: .polkaswapDexManagerDesInfos,
                    type: .u32
                )
                return UInt32(id)
            }
        })

        mapDexInfosOperation.addDependency(dexInfosOperation.targetOperation)

        let dependencies = [runtimeOperation] + dexInfosOperation.allOperations + [mapDexInfosOperation]

        return CompoundOperationWrapper(targetOperation: mapDexInfosOperation, dependencies: dependencies)
    }

    private func createDexInfosOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<DexIdInfo>]> {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        let dexInfosWrapper: CompoundOperationWrapper<[StorageResponse<DexIdInfo>]> =
            storageRequestFactory.queryItemsByPrefix(
                engine: connection,
                keys: { [try StorageKeyFactory().key(from: .polkaswapDexManagerDesInfos)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .polkaswapDexManagerDesInfos
            )

        dexInfosWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return dexInfosWrapper
    }
}
