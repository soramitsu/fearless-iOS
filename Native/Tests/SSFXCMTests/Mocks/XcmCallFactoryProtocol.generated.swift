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

public class XcmCallFactoryProtocolMock: XcmCallFactoryProtocol {
    public init() {}

    // MARK: - reserveNativeToken

    public var reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathThrowableError: Error?
    public var reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathCallsCount =
        0
    public var reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathCalled: Bool {
        reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathCallsCount >
            0
    }

    public var reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReceivedArguments: (
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    )?
    public var reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReceivedInvocations: [
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
    public var reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReturnValue: RuntimeCall<
        ReserveTransferAssetsCall
    >!
    public var reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathClosure: (
        (
            XcmCallFactoryVersion,
            String,
            ChainModel,
            ChainModel,
            AccountId,
            BigUInt,
            XcmCallPath
        ) throws -> RuntimeCall<ReserveTransferAssetsCall>
    )?

    public func reserveNativeToken(
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> RuntimeCall<ReserveTransferAssetsCall> {
        if let error =
            reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathThrowableError
        {
            throw error
        }
        reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathCallsCount +=
            1
        reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReceivedArguments =
            (
                version: version,
                assetSymbol: assetSymbol,
                fromChainModel: fromChainModel,
                destChainModel: destChainModel,
                destAccountId: destAccountId,
                amount: amount,
                path: path
            )
        reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReceivedInvocations
            .append((
                version: version,
                assetSymbol: assetSymbol,
                fromChainModel: fromChainModel,
                destChainModel: destChainModel,
                destAccountId: destAccountId,
                amount: amount,
                path: path
            ))
        return try reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathClosure
            .map { try $0(
                version,
                assetSymbol,
                fromChainModel,
                destChainModel,
                destAccountId,
                amount,
                path
            ) } ??
            reserveNativeTokenVersionAssetSymbolFromChainModelDestChainModelDestAccountIdAmountPathReturnValue
    }

    // MARK: - xTokensTransferMultiasset

    public var xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathThrowableError: Error?
    public var xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathCallsCount =
        0
    public var xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathCalled: Bool {
        xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathCallsCount >
            0
    }

    public var xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathReceivedArguments: (
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    )?
    public var xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathReceivedInvocations: [
        (
            version: XcmCallFactoryVersion,
            assetSymbol: String,
            accountId: AccountId,
            fromChainModel: ChainModel,
            destChainModel: ChainModel,
            amount: BigUInt,
            path: XcmCallPath
        )
    ] = []
    public var xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathReturnValue: RuntimeCall<
        XTokensTransferMultiassetCall
    >!
    public var xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathClosure: (
        (
            XcmCallFactoryVersion,
            String,
            AccountId,
            ChainModel,
            ChainModel,
            BigUInt,
            XcmCallPath
        ) throws -> RuntimeCall<XTokensTransferMultiassetCall>
    )?

    public func xTokensTransferMultiasset(
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> RuntimeCall<XTokensTransferMultiassetCall> {
        if let error =
            xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathThrowableError
        {
            throw error
        }
        xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathCallsCount +=
            1
        xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathReceivedArguments =
            (
                version: version,
                assetSymbol: assetSymbol,
                accountId: accountId,
                fromChainModel: fromChainModel,
                destChainModel: destChainModel,
                amount: amount,
                path: path
            )
        xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathReceivedInvocations
            .append((
                version: version,
                assetSymbol: assetSymbol,
                accountId: accountId,
                fromChainModel: fromChainModel,
                destChainModel: destChainModel,
                amount: amount,
                path: path
            ))
        return try xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathClosure
            .map { try $0(
                version,
                assetSymbol,
                accountId,
                fromChainModel,
                destChainModel,
                amount,
                path
            ) } ??
            xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountPathReturnValue
    }

    // MARK: - polkadotXcmLimitedReserveTransferAssets

    public var polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathThrowableError: Error?
    public var polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathCallsCount =
        0
    public var polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathCalled: Bool {
        polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathCallsCount >
            0
    }

    public var polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReceivedArguments: (
        fromChainModel: ChainModel,
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    )?
    public var polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReceivedInvocations: [
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
    public var polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReturnValue: RuntimeCall<
        ReserveTransferAssetsCall
    >!
    public var polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathClosure: (
        (
            ChainModel,
            XcmCallFactoryVersion,
            String,
            AccountId,
            ChainModel,
            BigUInt,
            XcmCallPath
        ) throws -> RuntimeCall<ReserveTransferAssetsCall>
    )?

    public func polkadotXcmLimitedReserveTransferAssets(
        fromChainModel: ChainModel,
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> RuntimeCall<ReserveTransferAssetsCall> {
        if let error =
            polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathThrowableError
        {
            throw error
        }
        polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathCallsCount +=
            1
        polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReceivedArguments =
            (
                fromChainModel: fromChainModel,
                version: version,
                assetSymbol: assetSymbol,
                accountId: accountId,
                destChainModel: destChainModel,
                amount: amount,
                path: path
            )
        polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReceivedInvocations
            .append((
                fromChainModel: fromChainModel,
                version: version,
                assetSymbol: assetSymbol,
                accountId: accountId,
                destChainModel: destChainModel,
                amount: amount,
                path: path
            ))
        return try polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathClosure
            .map { try $0(
                fromChainModel,
                version,
                assetSymbol,
                accountId,
                destChainModel,
                amount,
                path
            ) } ??
            polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountPathReturnValue
    }

    // MARK: - bridgeProxyBurn

    public var bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathThrowableError: Error?
    public var bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathCallsCount = 0
    public var bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathCalled: Bool {
        bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathCallsCount > 0
    }

    public var bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReceivedArguments: (
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    )?
    public var bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReceivedInvocations: [(
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    )] = []
    public var bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReturnValue: RuntimeCall<
        BridgeProxyBurnCall
    >!
    public var bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathClosure: ((
        String,
        ChainModel,
        AccountId,
        BigUInt,
        XcmCallPath
    ) throws -> RuntimeCall<BridgeProxyBurnCall>)?

    public func bridgeProxyBurn(
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> RuntimeCall<BridgeProxyBurnCall> {
        if let error = bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathThrowableError {
            throw error
        }
        bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathCallsCount += 1
        bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReceivedArguments = (
            currencyId: currencyId,
            destChainModel: destChainModel,
            accountId: accountId,
            amount: amount,
            path: path
        )
        bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReceivedInvocations.append((
            currencyId: currencyId,
            destChainModel: destChainModel,
            accountId: accountId,
            amount: amount,
            path: path
        ))
        return try bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathClosure.map { try $0(
            currencyId,
            destChainModel,
            accountId,
            amount,
            path
        ) } ?? bridgeProxyBurnCurrencyIdDestChainModelAccountIdAmountPathReturnValue
    }

    // MARK: - soraBridgeAppBurn

    public var soraBridgeAppBurnCurrencyIdAccountIdAmountPathCallsCount = 0
    public var soraBridgeAppBurnCurrencyIdAccountIdAmountPathCalled: Bool {
        soraBridgeAppBurnCurrencyIdAccountIdAmountPathCallsCount > 0
    }

    public var soraBridgeAppBurnCurrencyIdAccountIdAmountPathReceivedArguments: (
        currencyId: String?,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    )?
    public var soraBridgeAppBurnCurrencyIdAccountIdAmountPathReceivedInvocations: [(
        currencyId: String?,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    )] = []
    public var soraBridgeAppBurnCurrencyIdAccountIdAmountPathReturnValue: RuntimeCall<
        LiberlandBridgeProxyBurnCall
    >!
    public var soraBridgeAppBurnCurrencyIdAccountIdAmountPathClosure: ((
        String?,
        AccountId,
        BigUInt,
        XcmCallPath
    ) -> RuntimeCall<LiberlandBridgeProxyBurnCall>)?

    public func soraBridgeAppBurn(
        currencyId: String?,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) -> RuntimeCall<LiberlandBridgeProxyBurnCall> {
        soraBridgeAppBurnCurrencyIdAccountIdAmountPathCallsCount += 1
        soraBridgeAppBurnCurrencyIdAccountIdAmountPathReceivedArguments = (
            currencyId: currencyId,
            accountId: accountId,
            amount: amount,
            path: path
        )
        soraBridgeAppBurnCurrencyIdAccountIdAmountPathReceivedInvocations.append((
            currencyId: currencyId,
            accountId: accountId,
            amount: amount,
            path: path
        ))
        return soraBridgeAppBurnCurrencyIdAccountIdAmountPathClosure.map { $0(
            currencyId,
            accountId,
            amount,
            path
        ) } ?? soraBridgeAppBurnCurrencyIdAccountIdAmountPathReturnValue
    }
}
