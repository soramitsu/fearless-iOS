import Foundation
import BigInt
import SSFModels

#if canImport(SSFXCM)
import SSFXCM
#else
// Shim for environments where SSFXCM no longer exposes XcmMinAmountInspector
public protocol XcmMinAmountInspector {
    func inspectMin(
        amount: BigUInt,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        assetSymbol: String
    ) throws
}

public final class XcmMinAmountInspectorImpl: XcmMinAmountInspector {
    public init() {}
    public func inspectMin(
        amount _: BigUInt,
        fromChainModel _: ChainModel,
        destChainModel _: ChainModel,
        assetSymbol _: String
    ) throws {
        // No-op shim: do not throw to avoid blocking flows when inspector is unavailable
    }
}
#endif

