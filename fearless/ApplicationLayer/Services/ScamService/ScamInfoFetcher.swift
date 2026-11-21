import Foundation
import SSFModels

protocol ScamInfoFetching {
    func fetch(address: String, chain: ChainModel) async throws -> ScamInfo?
}

final class ScamInfoFetcher: ScamInfoFetching {
    private let scamServiceOperationFactory: ScamServiceOperationFactoryProtocol
    private let operationQueue = OperationQueue()

    init(scamServiceOperationFactory: ScamServiceOperationFactoryProtocol) {
        self.scamServiceOperationFactory = scamServiceOperationFactory
    }

    /// Looks the address up in the stored scam list only; no third-party service is asked.
    func fetch(address: String, chain _: ChainModel) async throws -> ScamInfo? {
        try? await fetchScamInfo(address: address)
    }

    // MARK: Private

    private func fetchScamInfo(address: String) async throws -> ScamInfo? {
        try await withCheckedThrowingContinuation { continuation in
            let operation = scamServiceOperationFactory.fetchScamInfoOperation(for: address)

            operation.completionBlock = {
                do {
                    let scamInfo = try operation.extractNoCancellableResultData()
                    continuation.resume(returning: scamInfo)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            operationQueue.addOperation(operation)
        }
    }
}
