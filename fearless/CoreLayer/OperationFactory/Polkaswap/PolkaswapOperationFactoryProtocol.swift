import Foundation
import FearlessUtils
import RobinHood

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
    private let engine: JSONRPCEngine
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    init(
        engine: JSONRPCEngine,
        storageRequestFactory: StorageRequestFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        self.engine = engine
        self.storageRequestFactory = storageRequestFactory
        self.runtimeService = runtimeService
    }

    func createIsPathAvailableOperation(
        dexId: UInt32,
        from fromAssetId: String,
        to toAssetId: String
    ) -> JSONRPCOperation<[PolkaswapJSON], Bool> {
        let parameters: [PolkaswapJSON] = [
            PolkaswapJSON(dexId),
            PolkaswapJSON(fromAssetId),
            PolkaswapJSON(toAssetId)
        ]

        return JSONRPCOperation<[PolkaswapJSON], Bool>(
            engine: engine,
            method: RPCMethod.checkIsSwapPossible,
            parameters: parameters
        )
    }

    func createGetAvailableMarketAlgorithmsOperation(
        dexId: UInt32,
        from fromAssetId: String,
        to toAssetId: String
    ) -> JSONRPCOperation<[PolkaswapJSON], [String]> {
        let parameters: [PolkaswapJSON] = [
            PolkaswapJSON(dexId),
            PolkaswapJSON(fromAssetId),
            PolkaswapJSON(toAssetId)
        ]

        return JSONRPCOperation<[PolkaswapJSON], [String]>(
            engine: engine,
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
            engine: engine,
            method: RPCMethod.recalculateSwapValues,
            parameters: paramsArray
        )
    }

    func createDexInfosOperation() -> CompoundOperationWrapper<[UInt32]> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()
        let dexInfosOperation = createDexInfosOperation(dependingOn: runtimeOperation)

        let mapDexInfosOperation = ClosureOperation<[UInt32]> {
            try dexInfosOperation.targetOperation.extractNoCancellableResultData().compactMap { storageResponse in
                let extractor = StorageKeyDataExtractor(storageKey: storageResponse.key)
                let id = try extractor.extractU32Parameter()
                return id
            }
        }

        mapDexInfosOperation.addDependency(dexInfosOperation.targetOperation)

        let dependencies = [runtimeOperation] + dexInfosOperation.allOperations + [mapDexInfosOperation]

        return CompoundOperationWrapper(targetOperation: mapDexInfosOperation, dependencies: dependencies)
    }

    private func createDexInfosOperation(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<DexIdInfo>]> {
        let dexInfosWrapper: CompoundOperationWrapper<[StorageResponse<DexIdInfo>]> =
            storageRequestFactory.queryItemsByPrefix(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .polkaswapDexManagerDesInfos)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .polkaswapDexManagerDesInfos
            )

        dexInfosWrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }

        return dexInfosWrapper
    }
}
