import Foundation
import RobinHood
import FearlessUtils

final class RuntimeRegistryService {
    private(set) var chain: Chain
    private(set) var isActive: Bool = false

    private let mutex = NSLock()

    let chainRegistry: ChainRegistryProtocol

    init(chain: Chain, chainRegistry: ChainRegistryProtocol) {
        self.chain = chain
        self.chainRegistry = chainRegistry
    }
}

extension RuntimeRegistryService: RuntimeRegistryServiceProtocol {
    func update(to chain: Chain) {
        mutex.lock()

        self.chain = chain

        mutex.unlock()
    }

    func setup() {
        mutex.lock()

        isActive = true

        mutex.unlock()
    }

    func throttle() {
        mutex.lock()

        isActive = false

        mutex.unlock()
    }
}

extension RuntimeRegistryService: RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return chainRegistry.getRuntimeProvider(for: chain.genesisHash)?.fetchCoderFactoryOperation() ??
            BaseOperation.createWithError(RuntimeProviderError.providerUnavailable)
    }
}
