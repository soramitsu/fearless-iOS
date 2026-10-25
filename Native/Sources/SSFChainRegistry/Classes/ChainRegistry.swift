import Foundation
import RobinHood
import SSFChainConnection
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import Web3

// sourcery: AutoMockable
public protocol ChainRegistryProtocol: AnyObject {
    func getRuntimeProvider(
        chainId: ChainModel.Id,
        usedRuntimePaths: [String: [String]],
        runtimeItem: RuntimeMetadataItemProtocol?
    ) async throws -> RuntimeProviderProtocol
    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?
    func getSubstrateConnection(for chain: ChainModel) throws -> SubstrateConnection
    func getEthereumConnection(for chain: ChainModel) throws -> Web3EthConnection
    func getChain(for chainId: ChainModel.Id) async throws -> ChainModel
    func getChains() async throws -> [ChainModel]
    func getReadySnapshot(
        chainId: ChainModel.Id,
        usedRuntimePaths: [String: [String]],
        runtimeItem: RuntimeMetadataItemProtocol?
    ) async throws -> RuntimeSnapshot
}

public final class ChainRegistry {
    private let runtimeProviderPool: RuntimeProviderPoolProtocol
    private let connectionPool: ConnectionPoolProtocol
    private let chainSyncService: ChainSyncServiceProtocol
    private let chainsTypesSyncService: ChainsTypesSyncServiceProtocol
    private let runtimeSyncService: RuntimeSyncServiceProtocol

    private let mutex = NSLock()

    private lazy var readLock = ReaderWriterLock()

    public init(
        runtimeProviderPool: RuntimeProviderPoolProtocol,
        connectionPool: ConnectionPoolProtocol,
        chainSyncService: ChainSyncServiceProtocol,
        chainsTypesSyncService: ChainsTypesSyncServiceProtocol,
        runtimeSyncService: RuntimeSyncServiceProtocol
    ) {
        self.runtimeProviderPool = runtimeProviderPool
        self.connectionPool = connectionPool
        self.chainSyncService = chainSyncService
        self.runtimeSyncService = runtimeSyncService
        self.chainsTypesSyncService = chainsTypesSyncService
        syncUpServices()
    }

    private func syncUpServices() {
        chainSyncService.syncUp()
        chainsTypesSyncService.syncUp()
    }
}

// MARK: - ChainRegistryProtocol

extension ChainRegistry: ChainRegistryProtocol {
    public func getRuntimeProvider(
        chainId: ChainModel.Id,
        usedRuntimePaths: [String: [String]],
        runtimeItem: RuntimeMetadataItemProtocol?
    ) async throws -> RuntimeProviderProtocol {
        if let cachedProvider = runtimeProviderPool.getRuntimeProvider(for: chainId) {
            return cachedProvider
        }
        
        let chainModel = try await chainSyncService.getChainModel(for: chainId)

        let runtimeMetadataItem: RuntimeMetadataItemProtocol
        if let runtimeItem = runtimeItem {
            runtimeMetadataItem = runtimeItem
        } else {
            let connection = try connectionPool.setupSubstrateConnection(for: chainModel)
            runtimeMetadataItem = try await runtimeSyncService.register(
                chain: chainModel,
                with: connection
            )
        }
        let chainTypes = try await chainsTypesSyncService.getTypes(for: chainId)
        let runtimeProvider = runtimeProviderPool.setupRuntimeProvider(
            for: runtimeMetadataItem,
            chainTypes: chainTypes,
            usedRuntimePaths: usedRuntimePaths
        )
        return runtimeProvider
    }

    public func getReadySnapshot(
        chainId: ChainModel.Id,
        usedRuntimePaths: [String: [String]],
        runtimeItem: RuntimeMetadataItemProtocol?
    ) async throws -> RuntimeSnapshot {
        let chainModel = try await chainSyncService.getChainModel(for: chainId)

        let runtimeMetadataItem: RuntimeMetadataItemProtocol
        if let runtimeItem = runtimeItem {
            runtimeMetadataItem = runtimeItem
        } else {
            let connection = try connectionPool.setupSubstrateConnection(for: chainModel)
            runtimeMetadataItem = try await runtimeSyncService.register(
                chain: chainModel,
                with: connection
            )
        }
        let chainTypes = try await chainsTypesSyncService.getTypes(for: chainId)
        let readySnaphot = try await runtimeProviderPool.readySnaphot(
            for: runtimeMetadataItem,
            chainTypes: chainTypes,
            usedRuntimePaths: usedRuntimePaths
        )
        return readySnaphot
    }

    public func getSubstrateConnection(for chain: ChainModel) throws -> SubstrateConnection {
        try connectionPool.setupSubstrateConnection(for: chain)
    }

    public func getEthereumConnection(
        for chain: SSFModels.ChainModel
    ) throws -> Web3EthConnection {
        try connectionPool.setupWeb3EthereumConnection(for: chain)
    }

    public func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        readLock.concurrentlyRead { runtimeProviderPool.getRuntimeProvider(for: chainId) }
    }

    public func getChain(for chainId: ChainModel.Id) async throws -> ChainModel {
        try await chainSyncService.getChainModel(for: chainId)
    }

    public func getChains() async throws -> [ChainModel] {
        try await chainSyncService.getChainModels()
    }
}
