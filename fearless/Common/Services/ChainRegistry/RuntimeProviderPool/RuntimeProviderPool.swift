import Foundation
import SSFModels
import SSFRuntimeCodingService

protocol RuntimeProviderPoolProtocol {
    @discardableResult
    func setupRuntimeProvider(
        for chain: ChainModel,
        chainTypes: Data?
    ) async -> RuntimeProviderProtocol
    @discardableResult
    func setupHotRuntimeProvider(
        for chain: ChainModel,
        runtimeItem: RuntimeMetadataItem,
        chainTypes: Data
    ) async -> RuntimeProviderProtocol
    func destroyRuntimeProvider(for chainId: ChainModel.Id) async
    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?
}

final actor RuntimeProviderPool {
    private let runtimeProviderFactory: RuntimeProviderFactoryProtocol

    private var usedRuntimeModules = UsedRuntimePaths()
    private(set) var runtimeProviders: [ChainModel.Id: RuntimeProviderProtocol] = [:]

    private let lock = ReaderWriterLock()

    init(runtimeProviderFactory: RuntimeProviderFactoryProtocol) {
        self.runtimeProviderFactory = runtimeProviderFactory
    }
    
    private func saveRuntimeProvider(provider: RuntimeProviderProtocol?, for chainId: ChainModel.Id) async {
        runtimeProviders[chainId] = provider
    }
}

extension RuntimeProviderPool: @preconcurrency RuntimeProviderPoolProtocol {
    @discardableResult
    func setupHotRuntimeProvider(
        for chain: ChainModel,
        runtimeItem: RuntimeMetadataItem,
        chainTypes: Data
    ) -> RuntimeProviderProtocol {
        let runtimeProvider = runtimeProviderFactory.createHotRuntimeProvider(
            for: chain,
            runtimeItem: runtimeItem,
            chainTypes: chainTypes,
            usedRuntimePaths: usedRuntimeModules.usedRuntimePaths
        )

        Task {
            await saveRuntimeProvider(provider: runtimeProvider, for: chain.chainId)
        }

        runtimeProvider.setupHot()

        return runtimeProvider
    }

    @discardableResult
    func setupRuntimeProvider(
        for chain: ChainModel,
        chainTypes: Data?
    ) -> RuntimeProviderProtocol {
        if let runtimeProvider = lock.concurrentlyRead({ runtimeProviders[chain.chainId] }) {
            return runtimeProvider
        } else {
            let runtimeProvider = runtimeProviderFactory.createRuntimeProvider(
                for: chain,
                chainTypes: chainTypes,
                usedRuntimePaths: usedRuntimeModules.usedRuntimePaths
            )

            Task {
                await saveRuntimeProvider(provider: runtimeProvider, for: chain.chainId)
            }

            runtimeProvider.setup()
            return runtimeProvider
        }
    }

    func destroyRuntimeProvider(for chainId: ChainModel.Id) {
        let runtimeProvider = lock.concurrentlyRead { runtimeProviders[chainId] }
        runtimeProvider?.cleanup()

        Task {
            await saveRuntimeProvider(provider: nil, for: chainId)
        }
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        runtimeProviders[chainId]
    }
}
