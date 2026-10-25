import BigInt
import Foundation
import RobinHood
import SSFModels
import SSFNetwork

// sourcery: AutoMockable
public protocol XcmDestinationFeeFetching {
    func estimateFee(
        destinationChainId: String,
        token: String
    ) async -> Result<DestXcmFee, Error>
}

public final class XcmDestinationFeeFetcher: XcmDestinationFeeFetching {
    private let sourceUrl: URL
    private let networkOperationFactory: NetworkOperationFactoryProtocol
    private let operationQueue: OperationQueue
    private let useCache: Bool

    private let lock = NSLock()
    private var fees: [XcmFee]?

    public init(
        sourceUrl: URL,
        networkOperationFactory: NetworkOperationFactoryProtocol,
        operationQueue: OperationQueue,
        useCache: Bool = true
    ) {
        self.sourceUrl = sourceUrl
        self.networkOperationFactory = networkOperationFactory
        self.operationQueue = operationQueue
        self.useCache = useCache
    }

    public func estimateFee(
        destinationChainId: String,
        token: String
    ) async -> Result<DestXcmFee, Error> {
        let remoteData = await fetchRemoteData()
        let fee = fetchFee(
            from: remoteData,
            destinationChainId: destinationChainId,
            token: token
        )
        return fee
    }

    // MARK: - Private methods

    private func fetchFee(
        from remoteData: Result<[XcmFee], Error>?,
        destinationChainId: String,
        token: String
    ) -> Result<DestXcmFee, Error> {
        switch remoteData {
        case let .success(feeList):
            guard let xcmFee = feeList.first(where: { $0.chainId == destinationChainId }),
                  let destXcmFee = xcmFee.destXcmFee.first(where: {
                      if $0.symbol.lowercased() == token.lowercased() {
                          return true
                      } else if token.lowercased().hasPrefix("xc") {
                          let modifySymbol = String(token.dropFirst(2)).lowercased()
                          return $0.symbol.lowercased() == modifySymbol.lowercased()
                      }
                      return false
                  }) else
            {
                return .failure(XcmError.noFee(chainId: destinationChainId))
            }

            return .success(destXcmFee)
        case let .failure(error):
            return .failure(error)
        case .none:
            return .failure(XcmError.missingRemoteFeeResult)
        }
    }

    private func fetchRemoteData() async -> Result<[XcmFee], Error>? {
        if useCache, let fees = cachedFees() {
            return .success(fees)
        }

        let networkOperation: BaseOperation<[XcmFee]> = networkOperationFactory
            .fetchData(from: sourceUrl)

        let result: Result<[XcmFee], Error>? = await withCheckedContinuation { continuation in
            // Set before the operation is queued: an operation that finishes first would
            // otherwise never call it, and this continuation would never resume.
            networkOperation.completionBlock = {
                let result = networkOperation.result
                continuation.resume(returning: result)
            }
            operationQueue.addOperation(networkOperation)
        }

        if case let .success(fees) = result {
            cache(fees)
        }

        return result
    }

    private func cachedFees() -> [XcmFee]? {
        lock.lock()
        defer { lock.unlock() }
        return fees
    }

    private func cache(_ fees: [XcmFee]) {
        lock.lock()
        defer { lock.unlock() }
        self.fees = fees
    }
}
