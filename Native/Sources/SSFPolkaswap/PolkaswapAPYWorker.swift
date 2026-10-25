import RobinHood
import sorawallet
import SSFUtils

enum PolkaswapAPYWorkerError: Swift.Error {
    case unexpectedError
}

public protocol PolkaswapAPYWorker {
    func getAPYInfo() async throws -> [SbApyInfo]
}

public final class PolkaswapAPYWorkerDefault: PolkaswapAPYWorker {
    private var subQueryClient: SoraWalletBlockExplorerInfo?

    public init(
        networkClient: SoramitsuNetworkClient,
        configBuilder: SoraRemoteConfigBuilder
    ) {
        subQueryClient = SoraWalletBlockExplorerInfo(
            networkClient: networkClient,
            soraRemoteConfigBuilder: configBuilder
        )
    }

    public func getAPYInfo() async throws -> [SbApyInfo] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                self?.subQueryClient?.getSpApy(completionHandler: { requestResult, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    if let data = requestResult {
                        continuation.resume(returning: data)
                        return
                    }

                    continuation.resume(throwing: PolkaswapAPYWorkerError.unexpectedError)
                })
            }
        }
    }
}
