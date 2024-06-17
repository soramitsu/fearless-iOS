import Foundation
import SSFModels
import SSFRuntimeCodingService

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

    private let lock = ReaderWriterLock()

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

        lock.exclusivelyWrite { [weak self] in
            self?.runtimeProviders[chain.chainId] = runtimeProvider
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

            lock.exclusivelyWrite { [weak self] in
                self?.runtimeProviders[chain.chainId] = runtimeProvider
            }

            runtimeProvider.setup()
            return runtimeProvider
        }
    }

    func destroyRuntimeProvider(for chainId: ChainModel.Id) {
        let runtimeProvider = runtimeProviders[chainId]
        runtimeProvider?.cleanup()

        lock.exclusivelyWrite { [weak self] in
            self?.runtimeProviders[chainId] = nil
        }
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        lock.concurrentlyRead {
            runtimeProviders[chainId]
        }
    }
}
