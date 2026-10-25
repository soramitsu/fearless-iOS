import Foundation
import RobinHood
import SSFChainConnection
import SSFChainRegistry
import SSFExtrinsicKit
import SSFModels
import SSFRuntimeCodingService
import SSFSigner
import SSFStorageQueryKit
import SSFUtils

struct XcmDeps {
    let extrinsicService: ExtrinsicServiceProtocol
}
// sourcery: AutoMockable
protocol XcmDependencyContainerProtocol: AnyObject {
    func prepareDeps() async throws -> XcmDeps
}

final class XcmDependencyContainer: XcmDependencyContainerProtocol {
    private let chainRegistry: ChainRegistryProtocol
    private let fromChainData: XcmAssembly.FromChainData

    private var connection: SubstrateConnection?

    init(
        chainRegistry: ChainRegistryProtocol,
        fromChainData: XcmAssembly.FromChainData
    ) {
        self.chainRegistry = chainRegistry
        self.fromChainData = fromChainData
    }

    func prepareDeps() async throws -> XcmDeps {
        let operationManager = OperationManager()
        let fromChainModel = try await chainRegistry.getChain(for: fromChainData.chainId)
        let runtimeRegistry = try await chainRegistry.getRuntimeProvider(
            chainId: fromChainModel.chainId,
            usedRuntimePaths: XcmCallPath.usedRuntimePaths,
            runtimeItem: fromChainData.chainMetadata
        )
        let engine = try await chainRegistry.getSubstrateConnection(for: fromChainModel)
        connection = engine

        let extrinsicService = ExtrinsicService(
            accountId: fromChainData.accountId,
            chainFormat: fromChainModel.chainFormat,
            cryptoType: fromChainData.cryptoType,
            runtimeRegistry: runtimeRegistry,
            engine: engine,
            operationManager: operationManager
        )

        return XcmDeps(extrinsicService: extrinsicService)
    }
}
