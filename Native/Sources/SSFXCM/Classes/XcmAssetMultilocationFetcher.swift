import Foundation
import RobinHood
import SSFModels
import SSFNetwork
import SSFUtils

// sourcery: AutoMockable
protocol XcmAssetMultilocationFetching {
    func versionedMultilocation(
        originAssetId: String,
        destChainId: ChainModel.Id
    ) async throws -> AssetMultilocation
}

/// Loads the token locations file on first use and keeps it. Concurrent callers wait for the same
/// load. A failed load is tried again while `retryStrategy` gives a delay, then reported; the next
/// call starts a new load.
final class XcmAssetMultilocationFetcher: XcmAssetMultilocationFetching {
    private enum LoadState {
        case loaded([RemoteAssetMultilocation])
        case loading(Task<[RemoteAssetMultilocation], Error>)
    }

    private let sourceUrl: URL
    private let dataFetchFactory: NetworkOperationFactoryProtocol
    private let retryStrategy: ReconnectionStrategyProtocol
    private let operationQueue: OperationQueue

    private let lock = NSLock()
    private var locations: [RemoteAssetMultilocation]?
    private var pendingLoad: Task<[RemoteAssetMultilocation], Error>?

    init(
        sourceUrl: URL,
        dataFetchFactory: NetworkOperationFactoryProtocol,
        retryStrategy: ReconnectionStrategyProtocol,
        operationQueue: OperationQueue
    ) {
        self.sourceUrl = sourceUrl
        self.dataFetchFactory = dataFetchFactory
        self.retryStrategy = retryStrategy
        self.operationQueue = operationQueue
    }

    // MARK: - Public methods

    func versionedMultilocation(
        originAssetId: String,
        destChainId: ChainModel.Id
    ) async throws -> AssetMultilocation {
        try search(
            in: await loadedLocations(),
            originAssetId: originAssetId,
            destChainId: destChainId
        )
    }

    // MARK: - Private methods

    private func search(
        in assetMultilocations: [RemoteAssetMultilocation],
        originAssetId: String,
        destChainId: ChainModel.Id
    ) throws -> AssetMultilocation {
        guard let multilocation = assetMultilocations.first(where: { remoteAssetMultilocation in
            remoteAssetMultilocation.chainId == destChainId
        })?.assets.first(where: { assetMultilocation in
            assetMultilocation.id == originAssetId
        }) else {
            throw XcmError.missingAssetLocationsResult
        }

        return multilocation
    }

    private func loadedLocations() async throws -> [RemoteAssetMultilocation] {
        switch currentLoad() {
        case let .loaded(locations):
            return locations
        case let .loading(load):
            let result = await load.result
            finish(load, with: result)
            return try result.get()
        }
    }

    private func currentLoad() -> LoadState {
        lock.lock()
        defer { lock.unlock() }

        if let locations {
            return .loaded(locations)
        }
        if let pendingLoad {
            return .loading(pendingLoad)
        }

        let load = Task { try await self.loadWithRetries() }
        pendingLoad = load
        return .loading(load)
    }

    private func finish(
        _ load: Task<[RemoteAssetMultilocation], Error>,
        with result: Result<[RemoteAssetMultilocation], Error>
    ) {
        lock.lock()
        defer { lock.unlock() }

        if pendingLoad == load {
            pendingLoad = nil
        }
        if case let .success(remoteLocations) = result {
            locations = remoteLocations
        }
    }

    private func loadWithRetries() async throws -> [RemoteAssetMultilocation] {
        var attempt = 0
        while true {
            do {
                return try await loadRemoteAssetLocations()
            } catch {
                attempt += 1
                guard let delay = retryStrategy.reconnectAfter(attempt: attempt) else {
                    throw error
                }
                try await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
            }
        }
    }

    private func loadRemoteAssetLocations() async throws -> [RemoteAssetMultilocation] {
        let networkOperation: BaseOperation<[RemoteAssetMultilocation]> = dataFetchFactory
            .fetchData(from: sourceUrl)

        return try await withCheckedThrowingContinuation { continuation in
            // Set before the operation is queued: an operation that finishes first would
            // otherwise never call it, and this continuation would never resume.
            networkOperation.completionBlock = {
                switch networkOperation.result {
                case let .success(assetMultilocation):
                    continuation.resume(with: .success(assetMultilocation))
                case let .failure(error):
                    continuation.resume(with: .failure(error))
                case .none:
                    continuation.resume(with: .failure(XcmError.missingAssetLocationsResult))
                }
            }
            operationQueue.addOperation(networkOperation)
        }
    }
}
