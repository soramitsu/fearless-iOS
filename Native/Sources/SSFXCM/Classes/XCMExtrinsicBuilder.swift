import BigInt
import Foundation
import SSFExtrinsicKit
import SSFModels

// sourcery: AutoMockable
protocol XcmExtrinsicBuilderProtocol {
    func buildReserveNativeTokenExtrinsicBuilderClosure(
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> ExtrinsicBuilderClosure

    func buildXTokensTransferMultiassetExtrinsicBuilderClosure(
        assetSymbol: String,
        version: XcmCallFactoryVersion,
        accountId: AccountId,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    ) async throws -> ExtrinsicBuilderClosure

    func buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosure(
        fromChainModel: ChainModel,
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    ) async throws -> ExtrinsicBuilderClosure

    func buildBridgeProxyBurn(
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> ExtrinsicBuilderClosure

    func buildSoraBridgeAddBurn(
        currencyId: String?,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) -> ExtrinsicBuilderClosure
}

final class XcmExtrinsicBuilder: XcmExtrinsicBuilderProtocol {
    private var callFactory: XcmCallFactoryProtocol

    public init(callFactory: XcmCallFactoryProtocol? = nil) {
        self.callFactory = callFactory ?? XcmCallFactory()
    }

    // MARK: - Public methods

    func buildReserveNativeTokenExtrinsicBuilderClosure(
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> ExtrinsicBuilderClosure {
        let call = try callFactory.reserveNativeToken(
            version: version,
            assetSymbol: assetSymbol,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel,
            destAccountId: destAccountId,
            amount: amount,
            path: path
        )

        return { builder in
            try builder.adding(call: call)
        }
    }

    func buildXTokensTransferMultiassetExtrinsicBuilderClosure(
        assetSymbol: String,
        version: XcmCallFactoryVersion,
        accountId: AccountId,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    ) async throws -> ExtrinsicBuilderClosure {
        let call = try await callFactory.xTokensTransferMultiasset(
            version: version,
            assetSymbol: assetSymbol,
            accountId: accountId,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel,
            amount: amount,
            path: path
        )

        return { builder in
            try builder.adding(call: call)
        }
    }

    func buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosure(
        fromChainModel: ChainModel,
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    ) async throws -> ExtrinsicBuilderClosure {
        let call = try await callFactory.polkadotXcmLimitedReserveTransferAssets(
            fromChainModel: fromChainModel,
            version: version,
            assetSymbol: assetSymbol,
            accountId: accountId,
            destChainModel: destChainModel,
            amount: amount,
            path: path
        )

        return { builder in
            try builder.adding(call: call)
        }
    }

    func buildBridgeProxyBurn(
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> ExtrinsicBuilderClosure {
        let call = try callFactory.bridgeProxyBurn(
            currencyId: currencyId,
            destChainModel: destChainModel,
            accountId: accountId,
            amount: amount,
            path: path
        )

        return { builder in
            try builder.adding(call: call)
        }
    }

    func buildSoraBridgeAddBurn(
        currencyId: String?,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) -> ExtrinsicBuilderClosure {
        let call = callFactory.soraBridgeAppBurn(
            currencyId: currencyId,
            accountId: accountId,
            amount: amount,
            path: path
        )

        return { builder in
            try builder.adding(call: call)
        }
    }
}
