import Foundation
import BigInt
import SSFModels

// Local app-level abstraction to avoid depending on SSFXCM's symbol availability.
public protocol AppXcmMinAmountInspector {
    func inspectMin(
        amount: BigUInt,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        assetSymbol: String
    ) throws
}

public final class AppXcmMinAmountInspectorImpl: AppXcmMinAmountInspector {
    public init() {}
    public func inspectMin(
        amount _: BigUInt,
        fromChainModel _: ChainModel,
        destChainModel _: ChainModel,
        assetSymbol _: String
    ) throws {
        // No-op: if minimum amount checks are required, wire in SSFXCM-backed inspector here.
    }
}
