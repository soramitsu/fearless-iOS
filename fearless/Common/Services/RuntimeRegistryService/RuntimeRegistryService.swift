// import Foundation
// import RobinHood
// import FearlessUtils
//
// enum RuntimeRegistryServiceError: Error {
//    case missingBaseTypes
//    case missingNetworkTypes
//    case brokenMetadata
//    case noNeedToUpdateTypes
//    case unexpectedCoderFetchingFailure
//    case timedOut
// }
//
// final class RuntimeRegistryService {
//    private(set) var chain: Chain
//    private(set) var isActive: Bool = false
//
//    private let mutex = NSLock()
//
//    let chainRegistry: ChainRegistryProtocol
//
//    init(chain: Chain, chainRegistry: ChainRegistryProtocol) {
//        self.chain = chain
//        self.chainRegistry = chainRegistry
//    }
//
//    private var chainRuntimeProvider: RuntimeProviderProtocol? {
//        chainRegistry.getRuntimeProvider(for: chain.genesisHash)
//    }
// }
//
// extension RuntimeRegistryService: RuntimeRegistryServiceProtocol {
//    func update(to chain: Chain) {
//        mutex.lock()
//
//        self.chain = chain
//
//        mutex.unlock()
//    }
//
//    func setup() {
//        mutex.lock()
//
//        isActive = true
//
//        mutex.unlock()
//    }
//
//    func throttle() {
//        mutex.lock()
//
//        isActive = false
//
//        mutex.unlock()
//    }
// }
//
// extension RuntimeRegistryService: RuntimeCodingServiceProtocol {
//    var snapshot: RuntimeSnapshot? {
//        chainRuntimeProvider?.snapshot
//    }
//
//    func fetchCoderFactoryOperation(
//        with _: TimeInterval,
//        closure _: RuntimeMetadataClosure?
//    ) -> BaseOperation<RuntimeCoderFactoryProtocol> {
//        chainRuntimeProvider?.fetchCoderFactoryOperation() ??
//            BaseOperation.createWithError(RuntimeProviderError.providerUnavailable)
//    }
//
//    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
//        mutex.lock()
//
//        defer {
//            mutex.unlock()
//        }
//
//        return chainRuntimeProvider?.fetchCoderFactoryOperation() ??
//            BaseOperation.createWithError(RuntimeProviderError.providerUnavailable)
//    }
// }
