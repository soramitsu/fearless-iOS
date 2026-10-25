// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import BigInt
@testable import RobinHood
@testable import SSFChainConnection
@testable import SSFChainRegistry
@testable import SSFExtrinsicKit
@testable import SSFModels
@testable import SSFNetwork
@testable import SSFRuntimeCodingService
@testable import SSFSigner
@testable import SSFStorageQueryKit
@testable import SSFUtils
@testable import SSFXCM

public class XcmExtrinsicBuilderProtocolMock: XcmExtrinsicBuilderProtocol {
    public init() {}

    // MARK: - buildReserveNativeTokenExtrinsicBuilderClosure

    public var buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathThrowableError: Error?
    public var buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathCallsCount =
        0
    public var buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathCalled: Bool {
        buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathCallsCount >
            0
    }

    public var buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReceivedArguments: (
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    )?
    public var buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReceivedInvocations: [
        (
            version: XcmCallFactoryVersion,
            assetSymbol: String,
            fromChainModel: ChainModel,
            destChainModel: ChainModel,
            destAccountId: AccountId,
            amount: BigUInt,
            path: XcmCallPath
        )
    ] = []
    public var buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReturnValue: ExtrinsicBuilderClosure!
    public var buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathClosure: (
        (
            XcmCallFactoryVersion,
            String,
            ChainModel,
            ChainModel,
            AccountId,
            BigUInt,
            XcmCallPath
        ) throws -> ExtrinsicBuilderClosure
    )?

    public func buildReserveNativeTokenExtrinsicBuilderClosure(
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> ExtrinsicBuilderClosure {
        if let error =
            buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathThrowableError
        {
            throw error
        }
        buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathCallsCount +=
            1
        buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReceivedArguments =
            (
                version: version,
                assetSymbol: assetSymbol,
                fromChainModel: fromChainModel,
                destChainModel: destChainModel,
                destAccountId: destAccountId,
                amount: amount,
                path: path
            )
        buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReceivedInvocations
            .append((
                version: version,
                assetSymbol: assetSymbol,
                fromChainModel: fromChainModel,
                destChainModel: destChainModel,
                destAccountId: destAccountId,
                amount: amount,
                path: path
            ))
        return try buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathClosure
            .map { try $0(
                version,
                assetSymbol,
                fromChainModel,
                destChainModel,
                destAccountId,
                amount,
                path
            ) } ??
            buildReserveNativeTokenExtrinsicBuilderClosureVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReturnValue
    }

    // MARK: - buildXTokensTransferMultiassetExtrinsicBuilderClosure

    public var buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathThrowableError: Error?
    public var buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathCallsCount =
        0
    public var buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathCalled: Bool {
        buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathCallsCount >
            0
    }

    public var buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathReceivedArguments: (
        assetSymbol: String,
        version: XcmCallFactoryVersion,
        accountId: AccountId,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    )?
    public var buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathReceivedInvocations: [
        (
            assetSymbol: String,
            version: XcmCallFactoryVersion,
            accountId: AccountId,
            fromChainModel: ChainModel,
            destChainModel: ChainModel,
            amount: BigUInt,
            path: XcmCallPath
        )
    ] = []
    public var buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathReturnValue: ExtrinsicBuilderClosure!
    public var buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathClosure: (
        (
            String,
            XcmCallFactoryVersion,
            AccountId,
            ChainModel,
            ChainModel,
            BigUInt,
            XcmCallPath
        ) throws -> ExtrinsicBuilderClosure
    )?

    public func buildXTokensTransferMultiassetExtrinsicBuilderClosure(
        assetSymbol: String,
        version: XcmCallFactoryVersion,
        accountId: AccountId,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> ExtrinsicBuilderClosure {
        if let error =
            buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathThrowableError
        {
            throw error
        }
        buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathCallsCount +=
            1
        buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathReceivedArguments =
            (
                assetSymbol: assetSymbol,
                version: version,
                accountId: accountId,
                fromChainModel: fromChainModel,
                destChainModel: destChainModel,
                amount: amount,
                path: path
            )
        buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathReceivedInvocations
            .append((
                assetSymbol: assetSymbol,
                version: version,
                accountId: accountId,
                fromChainModel: fromChainModel,
                destChainModel: destChainModel,
                amount: amount,
                path: path
            ))
        return try buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathClosure
            .map { try $0(
                assetSymbol,
                version,
                accountId,
                fromChainModel,
                destChainModel,
                amount,
                path
            ) } ??
            buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountPathReturnValue
    }

    // MARK: - buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosure

    public var buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathThrowableError: Error?
    public var buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathCallsCount =
        0
    public var buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathCalled: Bool {
        buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathCallsCount >
            0
    }

    public var buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReceivedArguments: (
        fromChainModel: ChainModel,
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    )?
    public var buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReceivedInvocations: [
        (
            fromChainModel: ChainModel,
            version: XcmCallFactoryVersion,
            assetSymbol: String,
            accountId: AccountId,
            destChainModel: ChainModel,
            amount: BigUInt,
            path: XcmCallPath
        )
    ] = []
    public var buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReturnValue: ExtrinsicBuilderClosure!
    public var buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathClosure: (
        (
            ChainModel,
            XcmCallFactoryVersion,
            String,
            AccountId,
            ChainModel,
            BigUInt,
            XcmCallPath
        ) throws -> ExtrinsicBuilderClosure
    )?

    public func buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosure(
        fromChainModel: ChainModel,
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> ExtrinsicBuilderClosure {
        if let error =
            buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathThrowableError
        {
            throw error
        }
        buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathCallsCount +=
            1
        buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReceivedArguments =
            (
                fromChainModel: fromChainModel,
                version: version,
                assetSymbol: assetSymbol,
                accountId: accountId,
                destChainModel: destChainModel,
                amount: amount,
                path: path
            )
        buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReceivedInvocations
            .append((
                fromChainModel: fromChainModel,
                version: version,
                assetSymbol: assetSymbol,
                accountId: accountId,
                destChainModel: destChainModel,
                amount: amount,
                path: path
            ))
        return try buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathClosure
            .map { try $0(
                fromChainModel,
                version,
                assetSymbol,
                accountId,
                destChainModel,
                amount,
                path
            ) } ??
            buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReturnValue
    }

    // MARK: - buildBridgeProxyBurn

    public var buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathThrowableError: Error?
    public var buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathCallsCount = 0
    public var buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathCalled: Bool {
        buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathCallsCount > 0
    }

    public var buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReceivedArguments: (
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    )?
    public var buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReceivedInvocations: [
        (
            currencyId: String,
            destChainModel: ChainModel,
            accountId: AccountId,
            amount: BigUInt,
            path: XcmCallPath
        )
    ] = []
    public var buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReturnValue: ExtrinsicBuilderClosure!
    public var buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathClosure: ((
        String,
        ChainModel,
        AccountId,
        BigUInt,
        XcmCallPath
    ) throws -> ExtrinsicBuilderClosure)?

    public func buildBridgeProxyBurn(
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> ExtrinsicBuilderClosure {
        if let error =
            buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathThrowableError
        {
            throw error
        }
        buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathCallsCount += 1
        buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReceivedArguments = (
            currencyId: currencyId,
            destChainModel: destChainModel,
            accountId: accountId,
            amount: amount,
            path: path
        )
        buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReceivedInvocations.append((
            currencyId: currencyId,
            destChainModel: destChainModel,
            accountId: accountId,
            amount: amount,
            path: path
        ))
        return try buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathClosure
            .map { try $0(
                currencyId,
                destChainModel,
                accountId,
                amount,
                path
            ) } ?? buildBridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReturnValue
    }

    // MARK: - buildSoraBridgeAddBurn

    public var buildSoraBridgeAddBurnCurrencyIdAccountIdAmountPathCallsCount = 0
    public var buildSoraBridgeAddBurnCurrencyIdAccountIdAmountPathCalled: Bool {
        buildSoraBridgeAddBurnCurrencyIdAccountIdAmountPathCallsCount > 0
    }

    public var buildSoraBridgeAddBurnCurrencyIdAccountIdAmountPathReceivedArguments: (
        currencyId: String?,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    )?
    public var buildSoraBridgeAddBurnCurrencyIdAccountIdAmountPathReceivedInvocations: [(
        currencyId: String?,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    )] = []
    public var buildSoraBridgeAddBurnCurrencyIdAccountIdAmountPathReturnValue: ExtrinsicBuilderClosure!
    public var buildSoraBridgeAddBurnCurrencyIdAccountIdAmountPathClosure: ((
        String?,
        AccountId,
        BigUInt,
        XcmCallPath
    ) -> ExtrinsicBuilderClosure)?

    public func buildSoraBridgeAddBurn(
        currencyId: String?,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) -> ExtrinsicBuilderClosure {
        buildSoraBridgeAddBurnCurrencyIdAccountIdAmountPathCallsCount += 1
        buildSoraBridgeAddBurnCurrencyIdAccountIdAmountPathReceivedArguments = (
            currencyId: currencyId,
            accountId: accountId,
            amount: amount,
            path: path
        )
        buildSoraBridgeAddBurnCurrencyIdAccountIdAmountPathReceivedInvocations.append((
            currencyId: currencyId,
            accountId: accountId,
            amount: amount,
            path: path
        ))
        return buildSoraBridgeAddBurnCurrencyIdAccountIdAmountPathClosure.map { $0(
            currencyId,
            accountId,
            amount,
            path
        ) } ?? buildSoraBridgeAddBurnCurrencyIdAccountIdAmountPathReturnValue
    }
}
