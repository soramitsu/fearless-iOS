import Foundation
import SSFChainRegistry
import SSFRuntimeCodingService

// sourcery: AutoMockable
protocol CallPathDeterminer {
    func determineCallPath(
        from: XcmChainType,
        dest: XcmChainType
    ) async throws -> XcmCallPath
}

/// Picks the call for a direction, and refuses the directions no call can serve any more.
///
/// Since the Asset Hub migration the relay chains keep their token's reserve on Asset Hub. A
/// reserve transfer of DOT or KSM from or to a relay chain is rejected on chain, so the only
/// relay chain transfers left are teleports to and from its system parachains.
final class CallPathDeterminerImpl: CallPathDeterminer {
    private enum Pallet: String {
        case xTokens
        case polkadotXcm
    }

    private let chainRegistry: ChainRegistryProtocol
    private let fromChainData: XcmAssembly.FromChainData

    init(
        chainRegistry: ChainRegistryProtocol,
        fromChainData: XcmAssembly.FromChainData
    ) {
        self.chainRegistry = chainRegistry
        self.fromChainData = fromChainData
    }

    // MARK: - Public methods

    func determineCallPath(
        from: XcmChainType,
        dest: XcmChainType
    ) async throws -> XcmCallPath {
        switch (from, dest) {
        case (.relaychain, .nativeParachain):
            return .xcmPalletLimitedTeleportAssets
        case (.nativeParachain, .relaychain):
            return .polkadotXcmLimitedTeleportAssets
        case (.nativeParachain, .nativeParachain):
            return .polkadotXcmLimitedTeleportAssets
        case (.nativeParachain, .parachain):
            return .polkadotXcmLimitedReserveTransferAssets
        case (.parachain, .nativeParachain):
            return try await determineForParachain(dest: dest)
        case (.parachain, .parachain):
            return try await determineForParachain(dest: dest)
        case (.parachain, .soraMainnet):
            return try await determineForParachain(dest: dest)
        case (.soraMainnet, .relaychain): // considers this case as Sora mainnet bridge
            return .bridgeProxyBurn
        case (.liberland, .soraMainnet):
            return .soraBridgeAppBurn
        case (.soraMainnet, .liberland):
            return .bridgeProxyBurn
        case (.soraMainnet, .parachain):
            return .bridgeProxyBurn
        case (.relaychain, .parachain), (.relaychain, .soraMainnet), (.parachain, .relaychain):
            // Reserve transfers of the relay chain's token through the relay chain.
            throw XcmError.directionNotSupported
        default:
            throw XcmError.directionNotSupported
        }
    }

    // MARK: - Private methods

    private func determineForParachain(
        dest: XcmChainType
    ) async throws -> XcmCallPath {
        let pallet = try await getPallet()
        switch (pallet, dest) {
        case (.xTokens, .nativeParachain):
            return .xTokensTransferMultiasset
        case (.xTokens, .parachain):
            return .xTokensTransferMultiasset
        case (.xTokens, .soraMainnet):
            return .xTokensTransferMultiasset
        case (.polkadotXcm, .nativeParachain):
            // A parachain is no trusted teleporter of the system parachains: assets go back to
            // Asset Hub by reserve transfer.
            return .polkadotXcmLimitedReserveTransferAssets
        case (.polkadotXcm, .parachain):
            return .polkadotXcmLimitedReserveTransferAssets
        default:
            throw XcmError.directionNotSupported
        }
    }

    private func getPallet() async throws -> Pallet {
        let metadata = try await getRuntimeSnapshot().metadata
        if metadata.getModuleIndex(Pallet.xTokens.rawValue) != nil {
            return Pallet.xTokens
        } else if metadata.getModuleIndex(Pallet.polkadotXcm.rawValue) != nil {
            return Pallet.polkadotXcm
        }
        throw XcmError.noXcmPallet(chainId: fromChainData.chainId)
    }

    private func getRuntimeSnapshot() async throws -> RuntimeSnapshot {
        try await chainRegistry.getReadySnapshot(
            chainId: fromChainData.chainId,
            usedRuntimePaths: XcmCallPath.usedRuntimePaths,
            runtimeItem: fromChainData.chainMetadata
        )
    }
}
