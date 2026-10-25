import BigInt
import Foundation
import IrohaCrypto
import SSFExtrinsicKit
import SSFModels
import SSFSigner

/// Read-only callers cannot obtain a transfer or signing method through this API.
public protocol XcmFeeEstimating {
    func estimateOriginalFee(
        fromChainId: String,
        assetSymbol: String,
        destChainId: String,
        destAccountId: AccountId,
        amount: BigUInt
    ) async -> FeeExtrinsicResult
}

public struct XcmReadOnlyServices {
    public let extrinsic: XcmFeeEstimating
    public let destinationFeeFetcher: XcmDestinationFeeFetching
    public let availableDestionationFetching: XcmChainsConfigFetching
}

public enum XcmReadOnlyError: Error {
    case signingUnavailable
}

/// Do not expose the underlying mutation-capable service by an existential
/// downcast. Its signer also rejects every attempt as defense in depth.
final class XcmReadOnlyFeeEstimator: XcmFeeEstimating {
    private let service: XcmExtrinsicServiceProtocol

    init(service: XcmExtrinsicServiceProtocol) { self.service = service }

    func estimateOriginalFee(
        fromChainId: String,
        assetSymbol: String,
        destChainId: String,
        destAccountId: AccountId,
        amount: BigUInt
    ) async -> FeeExtrinsicResult {
        await service.estimateOriginalFee(
            fromChainId: fromChainId, assetSymbol: assetSymbol,
            destChainId: destChainId, destAccountId: destAccountId, amount: amount
        )
    }
}

final class XcmReadOnlySigner: TransactionSignerProtocol {
    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        throw XcmReadOnlyError.signingUnavailable
    }
}
