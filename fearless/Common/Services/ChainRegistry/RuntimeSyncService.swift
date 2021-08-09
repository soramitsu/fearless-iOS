import Foundation
import RobinHood

protocol RuntimeSyncServiceProtocol {
    func register(chain: ChainModel, with connection: ChainConnection)
    func apply(version: RuntimeVersion, for chainId: ChainModel.Id)
}

final class RuntimeSyncService {
    struct SyncInfo {
        let typesURL: URL
        let connection: JSONRPCEngine
    }

    let repository: AnyDataProviderRepository<RuntimeMetadataItem>
    let operationQueue: OperationQueue

    private(set) var knownChains: [ChainModel.Id: SyncInfo] = [:]
    private var mutex = NSLock()

    init(
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        maxConcurrentSyncRequests: Int = 8
    ) {
        self.repository = repository

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = maxConcurrentSyncRequests
        operationQueue.qualityOfService = .userInitiated
        self.operationQueue = operationQueue
    }

    private func performSync(for _: ChainModel.Id, newVersion _: RuntimeVersion? = nil) {
        // TODO: Will be implemented in FLW-1193
    }
}

extension RuntimeSyncService: RuntimeSyncServiceProtocol {
    func register(chain: ChainModel, with connection: ChainConnection) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let syncInfo = knownChains[chain.chainId] else {
            knownChains[chain.chainId] = SyncInfo(typesURL: chain.typesURL, connection: connection)
            return
        }

        if syncInfo.typesURL != chain.typesURL {
            knownChains[chain.chainId] = SyncInfo(typesURL: chain.typesURL, connection: connection)

            performSync(for: chain.chainId)
        }
    }

    func apply(version: RuntimeVersion, for chainId: ChainModel.Id) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSync(for: chainId, newVersion: version)
    }
}
