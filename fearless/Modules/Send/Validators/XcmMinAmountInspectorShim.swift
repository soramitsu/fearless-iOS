import Foundation
import BigInt
import SSFModels

// Local app-level abstraction to avoid depending on SSFXCM's symbol availability.
public enum AppXcmMinAmountError: Error {
    case minAmountError(String)
}

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
        amount: BigUInt,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        assetSymbol: String
    ) throws {
        guard
            let rule = Self.minAmountRule(
                fromChainId: fromChainModel.chainId,
                destChainId: destChainModel.chainId
            ),
            let precision = Self.assetPrecision(
                for: assetSymbol,
                fromChainModel: fromChainModel,
                destChainModel: destChainModel
            ),
            let minAmount = Decimal(string: rule.minAmount)
                ?.toSubstrateAmount(precision: precision)
        else {
            return
        }

        guard amount >= minAmount else {
            throw AppXcmMinAmountError.minAmountError(rule.displayText)
        }
    }
}

private extension AppXcmMinAmountInspectorImpl {
    struct MinAmountRule {
        let minAmount: String
        let displayText: String
    }

    static func minAmountRule(
        fromChainId: ChainModel.Id,
        destChainId: ChainModel.Id
    ) -> MinAmountRule? {
        let fromChain = Chain(chainId: fromChainId)
        let destChain = Chain(chainId: destChainId)

        switch (fromChain, destChain) {
        case (.kusama, .soraMain):
            return MinAmountRule(minAmount: "0.05", displayText: "0.05 KSM")
        case (.polkadot, .soraMain), (.soraMain, .polkadot):
            return MinAmountRule(minAmount: "1.1", displayText: "1.1 DOT")
        case (.liberland, .soraMain), (.soraMain, .liberland):
            return MinAmountRule(minAmount: "1.0", displayText: "1.0 LLD")
        case (.soraMain, .acala):
            return MinAmountRule(minAmount: "1.0", displayText: "1.0 ACA")
        case (.acala, .soraMain):
            return MinAmountRule(minAmount: "56.0", displayText: "56.0 ACA")
        default:
            return nil
        }
    }

    static func assetPrecision(
        for assetSymbol: String,
        fromChainModel: ChainModel,
        destChainModel: ChainModel
    ) -> Int16? {
        let normalizedSymbol = assetSymbol.uppercased()

        let matchingAsset = fromChainModel.assets.first {
            $0.symbolUppercased == normalizedSymbol
        } ?? destChainModel.assets.first {
            $0.symbolUppercased == normalizedSymbol
        }

        return matchingAsset.map { Int16($0.precision) }
    }
}
