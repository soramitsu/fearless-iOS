import Foundation

protocol ScamInfoFetching {
    func fetch(address: String) async throws -> ScamInfo?
}

final class ScamInfoFetcher: ScamInfoFetching {
    private let scamServiceOperationFactory: ScamServiceOperationFactoryProtocol
    private let accountScoreFetching: AccountStatisticsFetching
    private let operationQueue = OperationQueue()

    init(
        scamServiceOperationFactory: ScamServiceOperationFactoryProtocol,
        accountScoreFetching: AccountStatisticsFetching
    ) {
        self.scamServiceOperationFactory = scamServiceOperationFactory
        self.accountScoreFetching = accountScoreFetching
    }

    func fetch(address: String) async throws -> ScamInfo? {
        let scamFeatureCheckingResult = try? await fetchScamInfo(address: address)

        guard scamFeatureCheckingResult == nil else {
            return scamFeatureCheckingResult
        }

        return try? await fetchAccountScore(address: address)
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

    private func fetchAccountScore(address: String) async throws -> ScamInfo? {
        let score: AccountStatisticsResponse? = try await accountScoreFetching.fetchStatistics(address: address)
        let scamInfo: ScamInfo? = score.flatMap {
            guard ($0.data?.score).or(.zero) < 25 else {
                return nil
            }

            return ScamInfo(name: "Low score", address: address, type: .lowScore, subtype: "Low network activity")
        }

        return scamInfo
    }
}
