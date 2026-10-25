import BigInt
import Foundation
import RobinHood
import SSFChainRegistry
import SSFCrypto
import SSFExtrinsicKit
import SSFModels
import SSFRuntimeCodingService
import SSFSigner
import SSFUtils

public protocol XcmExtrinsicServiceProtocol: XcmFeeEstimating {
    func transfer(
        fromChainId: String,
        assetSymbol: String,
        destChainId: String,
        destAccountId: AccountId,
        amount: BigUInt
    ) async -> SubmitExtrinsicResult
}

final class XcmExtrinsicService: XcmExtrinsicServiceProtocol {
    private let extrinsicBuilder: XcmExtrinsicBuilderProtocol
    private let signingWrapper: TransactionSignerProtocol
    private let xcmVersionFetcher: XcmVersionFetching
    private let chainRegistry: ChainRegistryProtocol
    private let depsContainer: XcmDependencyContainerProtocol
    private let callPathDeterminer: CallPathDeterminer

    init(
        signingWrapper: TransactionSignerProtocol,
        extrinsicBuilder: XcmExtrinsicBuilderProtocol,
        xcmVersionFetcher: XcmVersionFetching,
        chainRegistry: ChainRegistryProtocol,
        depsContainer: XcmDependencyContainerProtocol,
        callPathDeterminer: CallPathDeterminer
    ) {
        self.signingWrapper = signingWrapper
        self.extrinsicBuilder = extrinsicBuilder
        self.xcmVersionFetcher = xcmVersionFetcher
        self.chainRegistry = chainRegistry
        self.depsContainer = depsContainer
        self.callPathDeterminer = callPathDeterminer
    }

    // MARK: - Public methods

    func estimateOriginalFee(
        fromChainId: String,
        assetSymbol: String,
        destChainId: String,
        destAccountId: AccountId,
        amount: BigUInt
    ) async -> FeeExtrinsicResult {
        do {
            let extrinsic = try await makeExtrinsic(
                fromChainId: fromChainId,
                assetSymbol: assetSymbol,
                destChainId: destChainId,
                destAccountId: destAccountId,
                amount: amount
            )
            let extrinsicService = try await depsContainer.prepareDeps().extrinsicService

            return await withCheckedContinuation { continuation in
                extrinsicService.estimateFee(extrinsic, runningIn: .global()) { result in
                    continuation.resume(returning: result)
                }
            }
        } catch {
            return .failure(error)
        }
    }

    public func transfer(
        fromChainId: String,
        assetSymbol: String,
        destChainId: String,
        destAccountId: AccountId,
        amount: BigUInt
    ) async -> SubmitExtrinsicResult {
        do {
            let extrinsic = try await makeExtrinsic(
                fromChainId: fromChainId,
                assetSymbol: assetSymbol,
                destChainId: destChainId,
                destAccountId: destAccountId,
                amount: amount
            )
            let extrinsicService = try await depsContainer.prepareDeps().extrinsicService

            return await withCheckedContinuation { continuation in
                extrinsicService.submit(
                    extrinsic,
                    signer: signingWrapper,
                    runningIn: .global()
                ) { result in
                    continuation.resume(returning: result)
                }
            }
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Private methods

    /// The call for the route from `fromChainId` to `destChainId`, as `CallPathDeterminer` picks
    /// it. A fee quote and a transfer build the same call.
    private func makeExtrinsic(
        fromChainId: String,
        assetSymbol: String,
        destChainId: String,
        destAccountId: AccountId,
        amount: BigUInt
    ) async throws -> ExtrinsicBuilderClosure {
        let fromChainModel = try await chainRegistry.getChain(for: fromChainId)
        let destChainModel = try await chainRegistry.getChain(for: destChainId)
        let fromChainType = try XcmChainType.determineChainType(for: fromChainModel)
        let destChainType = try XcmChainType.determineChainType(for: destChainModel)
        let callPath = try await callPathDeterminer.determineCallPath(
            from: fromChainType,
            dest: destChainType
        )

        switch callPath {
        case .xcmPalletLimitedTeleportAssets, .polkadotXcmLimitedTeleportAssets:
            let version = try await xcmVersionFetcher.getVersion(for: fromChainModel.chainId)
            return try extrinsicBuilder.buildReserveNativeTokenExtrinsicBuilderClosure(
                version: version,
                assetSymbol: assetSymbol,
                fromChainModel: fromChainModel,
                destChainModel: destChainModel,
                destAccountId: destAccountId,
                amount: amount,
                path: callPath
            )
        case .xTokensTransferMultiasset:
            // SORA is reached through its parachain.
            let destination = destChainType == .soraMainnet
                ? try await getSoraParachainModel(
                    fromChainModel: fromChainModel,
                    destChainId: destChainId
                )
                : destChainModel
            let version = try await xcmVersionFetcher.getVersion(for: fromChainModel.chainId)
            return try await extrinsicBuilder.buildXTokensTransferMultiassetExtrinsicBuilderClosure(
                assetSymbol: assetSymbol.dropXcPrefix(chain: fromChainModel),
                version: version,
                accountId: destAccountId,
                fromChainModel: fromChainModel,
                destChainModel: destination,
                amount: amount,
                path: callPath
            )
        case .polkadotXcmLimitedReserveTransferAssets:
            let version = try await xcmVersionFetcher.getVersion(for: fromChainModel.chainId)
            return try await extrinsicBuilder
                .buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosure(
                    fromChainModel: fromChainModel,
                    version: version,
                    assetSymbol: assetSymbol.dropXcPrefix(chain: fromChainModel),
                    accountId: destAccountId,
                    destChainModel: destChainModel,
                    amount: amount,
                    path: callPath
                )
        case .bridgeProxyBurn:
            guard let currencyId = fromChainModel.assets
                .first(where: { $0.symbol.lowercased() == assetSymbol.lowercased() })?
                .currencyId else
            {
                throw XcmError.missingCurrencyId
            }
            return try extrinsicBuilder.buildBridgeProxyBurn(
                currencyId: currencyId,
                destChainModel: destChainModel,
                accountId: destAccountId,
                amount: amount,
                path: callPath
            )
        case .soraBridgeAppBurn:
            let currencyId = fromChainModel.assets
                .first(where: { $0.symbol.lowercased() == assetSymbol.lowercased() })?
                .currencyId
            return extrinsicBuilder.buildSoraBridgeAddBurn(
                currencyId: currencyId,
                accountId: destAccountId,
                amount: amount,
                path: callPath
            )
        case .parachainId, .bridgeProxyTransactions:
            throw XcmError.caseNotProcessed
        }
    }

    private func getSoraParachainModel(
        fromChainModel: ChainModel,
        destChainId: String
    ) async throws -> ChainModel {
        guard let bridgeParachainId = fromChainModel.xcm?.availableDestinations
            .first(where: { $0.chainId == destChainId })?.bridgeParachainId else
        {
            throw XcmError.convenience(error: "missing bridgeParachainId")
        }
        let soraParachainModel = try await chainRegistry.getChain(for: bridgeParachainId)
        return soraParachainModel
    }
}

private extension String {
    func dropXcPrefix(chain: ChainModel) -> String {
        guard chain.hasXcAssetPrefix else {
            return self
        }
        guard lowercased().hasPrefix("xc") else {
            return self
        }
        let modifySymbol = String(dropFirst(2))
        return modifySymbol
    }
}
