import Foundation

protocol RuntimeProviderPoolProtocol {
    func getWalletRuntime(for chain: ChainModel) -> RuntimeProviderProtocol
    func getFullRuntime(for chain: ChainModel) -> RuntimeProviderProtocol
}

final class RuntimeProviderPool {
    let cacheLimit: Int
    let runtimeProviderFactory: RuntimeProviderFactoryProtocol

    init(cacheLimit: Int, runtimeProviderFactory: RuntimeProviderFactoryProtocol) {
        self.cacheLimit = cacheLimit
        self.runtimeProviderFactory = runtimeProviderFactory
    }
}

extension RuntimeProviderPool: RuntimeProviderPoolProtocol {
    func getWalletRuntime(for chain: ChainModel) -> RuntimeProviderProtocol {
        runtimeProviderFactory.createRuntimeProvider(for: chain)
    }

    func getFullRuntime(for chain: ChainModel) -> RuntimeProviderProtocol {
        runtimeProviderFactory.createRuntimeProvider(for: chain)
    }
}
