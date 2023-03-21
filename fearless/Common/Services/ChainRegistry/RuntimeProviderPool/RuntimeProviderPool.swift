import Foundation

protocol RuntimeProviderPoolProtocol {
    @discardableResult
    func setupRuntimeProvider(
        for chain: ChainModel,
        chainTypes: Data?
    ) -> RuntimeProviderProtocol
    @discardableResult
    func setupHotRuntimeProvider(
        for chain: ChainModel,
        runtimeItem: RuntimeMetadataItem,
        chainTypes: Data
    ) -> RuntimeProviderProtocol
    func destroyRuntimeProvider(for chainId: ChainModel.Id)
    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?
}

final class RuntimeProviderPool {
    private let runtimeProviderFactory: RuntimeProviderFactoryProtocol

    private var usedRuntimeModules = UsedRuntimePaths()
    private(set) var runtimeProviders: [ChainModel.Id: RuntimeProviderProtocol] = [:]

    private let mutex = NSLock()

    init(runtimeProviderFactory: RuntimeProviderFactoryProtocol) {
        self.runtimeProviderFactory = runtimeProviderFactory
    }
}

extension RuntimeProviderPool: RuntimeProviderPoolProtocol {
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

        runtimeProviders[chain.chainId] = runtimeProvider

        runtimeProvider.setupHot()

        return runtimeProvider
    }

    @discardableResult
    func setupRuntimeProvider(
        for chain: ChainModel,
        chainTypes: Data?
    ) -> RuntimeProviderProtocol {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let runtimeProvider = runtimeProviders[chain.chainId] {
            return runtimeProvider
        } else {
            let runtimeProvider = runtimeProviderFactory.createRuntimeProvider(
                for: chain,
                chainTypes: chainTypes,
                usedRuntimePaths: usedRuntimeModules.usedRuntimePaths
            )

            runtimeProviders[chain.chainId] = runtimeProvider
            runtimeProvider.setup()
            return runtimeProvider
        }
    }

    func destroyRuntimeProvider(for chainId: ChainModel.Id) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let runtimeProvider = runtimeProviders[chainId]
        runtimeProvider?.cleanup()

        runtimeProviders[chainId] = nil
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return runtimeProviders[chainId]
    }
}
