import BigInt
import Foundation
import SSFModels
import SSFNetwork
import SSFUtils

// sourcery: AutoMockable
protocol XcmCallFactoryProtocol {
    func reserveNativeToken(
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> RuntimeCall<ReserveTransferAssetsCall>

    func xTokensTransferMultiasset(
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    ) async throws -> RuntimeCall<XTokensTransferMultiassetCall>

    func polkadotXcmLimitedReserveTransferAssets(
        fromChainModel: ChainModel,
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    ) async throws -> RuntimeCall<ReserveTransferAssetsCall>

    func bridgeProxyBurn(
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> RuntimeCall<BridgeProxyBurnCall>

    func soraBridgeAppBurn(
        currencyId: String?,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) -> RuntimeCall<LiberlandBridgeProxyBurnCall>
}

/// Builds the cross-chain transfer calls, and refuses what a live runtime would reject:
///
/// - XCM V3, V4 and V5 only; no runtime accepts V1 or V2 any more.
/// - Locations are relative to the origin chain, and both chains must belong to one relay network.
/// - `WeightLimit::Unlimited`: the destination buys the weight the message needs with the
///   transferred asset, instead of the whole of a guessed limit.
/// - No reserve transfer of the relay chain's token. Since the Asset Hub migration it is rejected
///   on chain (`Filtered`, `InvalidAssetUnknownReserve`); it needs
///   `transfer_assets_using_type_and_then` with an explicit reserve, which is not built here.
final class XcmCallFactory: XcmCallFactoryProtocol {
    private enum Constants {
        /// Load attempts for the token locations file before a call fails.
        static let tokenLocationsLoadAttempts = 3
        /// `data` of a V3 and later `GeneralKey` is `[u8; 32]`.
        static let generalKeyLength = 32
    }

    private let assetMultilocationFetcher: XcmAssetMultilocationFetching

    init(
        assetMultilocationFetcher: XcmAssetMultilocationFetching? = nil,
        tokenLocationsSourceUrl: URL = XcmConfig.shared.tokenLocationsSourceUrl
    ) {
        self.assetMultilocationFetcher = assetMultilocationFetcher ??
            XcmAssetMultilocationFetcher(
                sourceUrl: tokenLocationsSourceUrl,
                dataFetchFactory: NetworkOperationFactory(),
                retryStrategy: ExponentialReconnection(
                    maxAttempts: Constants.tokenLocationsLoadAttempts
                ),
                operationQueue: OperationQueue()
            )
    }

    // MARK: - Public methods

    /// Teleport of the relay chain's token between the relay chain and a system parachain, or
    /// between two system parachains.
    func reserveNativeToken(
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> RuntimeCall<ReserveTransferAssetsCall> {
        let version = try SupportedXcmVersion(version)
        let origin = try XcmChainPosition(fromChainModel)
        let destination = try XcmChainPosition(destChainModel)
        try origin.checkSameNetwork(as: destination)

        // Only the relay chain and its system parachains trust each other's teleports.
        guard origin.paraId != nil || destination.paraId != nil,
              origin.isRelayChainOrSystemParachain,
              destination.isRelayChainOrSystemParachain else
        {
            throw XcmError.directionNotSupported
        }

        // These calls move the relay chain's token, which is the utility asset of the relay
        // chain and of its system parachains. Any other asset would silently become that token.
        guard fromChainModel.utilityAssets().contains(where: {
            $0.symbol.lowercased() == assetSymbol.lowercased()
        }) else {
            throw XcmError.noAvailableXcmAsset(symbol: assetSymbol)
        }

        let relayToken = XcmV1MultiLocation(
            parents: origin.parentsToRelayChain,
            interior: XcmV1MultilocationJunctions(items: [])
        )

        let args = try ReserveTransferAssetsCall(
            destination: version.location(
                parents: origin.parentsToRelayChain,
                junctions: destination.junctions
            ),
            beneficiary: version.location(
                parents: 0,
                junctions: [createAccountJunction(
                    version: version,
                    accountId: destAccountId,
                    chainModel: destChainModel
                )]
            ),
            assets: version.assets([XcmV1MultiAsset(multilocation: relayToken, amount: amount)]),
            weightLimit: .unlimited,
            feeAssetItem: 0
        )

        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.itemName,
            args: args
        )
    }

    func xTokensTransferMultiasset(
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    ) async throws -> RuntimeCall<XTokensTransferMultiassetCall> {
        let version = try SupportedXcmVersion(version)
        let origin = try XcmChainPosition(fromChainModel)
        let destination = try XcmChainPosition(destChainModel)
        try origin.checkSameNetwork(as: destination)

        // The `dest_weight: u64` form of `transfer_multiasset` is gone from every runtime.
        guard fromChainModel.xcm?.destWeightIsPrimitive != true else {
            throw XcmError.unsupportedRemoteXcmVersion
        }

        let assetLocation = try await remoteAssetLocation(
            symbol: assetSymbol,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel
        )
        try origin.checkReserveTransferable(assetLocation)

        // XTokens takes the destination and the recipient in one location.
        let accountJunction = try createAccountJunction(
            version: version,
            accountId: accountId,
            chainModel: destChainModel
        )
        let args = try XTokensTransferMultiassetCall(
            asset: version.asset(XcmV1MultiAsset(multilocation: assetLocation, amount: amount)),
            dest: version.location(
                parents: origin.parentsToRelayChain,
                junctions: destination.junctions + [accountJunction]
            ),
            destWeightLimit: .unlimited
        )

        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.itemName,
            args: args
        )
    }

    func polkadotXcmLimitedReserveTransferAssets(
        fromChainModel: ChainModel,
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId,
        destChainModel: ChainModel,
        amount: BigUInt,
        path: XcmCallPath
    ) async throws -> RuntimeCall<ReserveTransferAssetsCall> {
        let version = try SupportedXcmVersion(version)
        let origin = try XcmChainPosition(fromChainModel)
        let destination = try XcmChainPosition(destChainModel)
        try origin.checkSameNetwork(as: destination)

        // There is no pallet_xcm reserve transfer to the relay chain (see `CallPathDeterminer`).
        guard let destParaId = destination.paraId else {
            throw XcmError.directionNotSupported
        }

        let assetLocation = try await remoteAssetLocation(
            symbol: assetSymbol,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel
        )
        try origin.checkReserveTransferable(assetLocation)

        let args = try ReserveTransferAssetsCall(
            destination: version.location(
                parents: origin.parentsToRelayChain,
                junctions: [.parachain(destParaId)]
            ),
            beneficiary: version.location(
                parents: 0,
                junctions: [createAccountJunction(
                    version: version,
                    accountId: accountId,
                    chainModel: destChainModel
                )]
            ),
            assets: version.assets([XcmV1MultiAsset(multilocation: assetLocation, amount: amount)]),
            weightLimit: .unlimited,
            feeAssetItem: 0
        )

        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.itemName,
            args: args
        )
    }

    func bridgeProxyBurn(
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> RuntimeCall<BridgeProxyBurnCall> {
        let networkId = try BridgeTypesGenericNetworkId(from: destChainModel)
        let assetId = SoraAssetId(wrappedValue: currencyId)

        let recipient: BridgeTypesGenericAccount
        switch networkId {
        case .evm:
            guard accountId.count == EthereumConstants.accountIdLength else {
                throw XcmError.invalidRecipientLength(
                    expected: EthereumConstants.accountIdLength,
                    actual: accountId.count
                )
            }
            recipient = .evm(accountId)
        case .sub(.liberland):
            recipient = .liberland(accountId)
        case .sub(.mainnet):
            throw XcmError.directionNotSupported
        case .sub:
            // The burn is delivered by SORA's parachain to a location relative to it: parents 1,
            // then X1(AccountId32) for the relay chain or X2(Parachain, AccountId32) for a
            // parachain, the shape of every completed burn. It stays V3, the version the
            // wallet's reviewed burn builds.
            let destination = try XcmChainPosition(destChainModel)
            let accountJunction = try createAccountJunction(
                version: .v3,
                accountId: accountId,
                chainModel: destChainModel
            )
            recipient = try .parachain(SupportedXcmVersion.v3.location(
                parents: 1,
                junctions: destination.junctions + [accountJunction]
            ))
        }

        let args = BridgeProxyBurnCall(
            networkId: networkId,
            assetId: assetId,
            recipient: recipient,
            amount: amount
        )

        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.itemName,
            args: args
        )
    }

    func soraBridgeAppBurn(
        currencyId: String?,
        accountId: AccountId,
        amount: BigUInt,
        path: XcmCallPath
    ) -> RuntimeCall<LiberlandBridgeProxyBurnCall> {
        let args = LiberlandBridgeProxyBurnCall(
            networkId: .mainnet,
            assetId: .init(currencyId: currencyId),
            recipient: .sora(accountId),
            amount: amount
        )

        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.itemName,
            args: args
        )
    }

    // MARK: - Private methods

    private func createAccountJunction(
        version: SupportedXcmVersion,
        accountId: AccountId,
        chainModel: ChainModel
    ) throws -> XcmJunction {
        let expectedLength = chainModel.isEthereumBased
            ? EthereumConstants.accountIdLength
            : SubstrateConstants.accountIdLength
        guard accountId.count == expectedLength else {
            throw XcmError.invalidRecipientLength(expected: expectedLength, actual: accountId.count)
        }

        let network = XcmJunctionNetworkId.from(
            ecosystem: ChainEcosystem.defineEcosystem(chain: chainModel),
            version: version.factoryVersion
        )

        if chainModel.isEthereumBased {
            return .accountKey20(AccountId20Value(network: network, key: accountId))
        } else {
            return .accountId32(AccountId32Value(network: network, accountId: accountId))
        }
    }

    /// The location of the asset to send as seen from the origin chain, from the token locations
    /// file. The file's own `parents` wins; without one, a location with no junctions or one that
    /// goes through a parachain is reached through the parent.
    private func remoteAssetLocation(
        symbol: String,
        fromChainModel: ChainModel,
        destChainModel: ChainModel
    ) async throws -> XcmV1MultiLocation {
        guard let originAssetId = fromChainModel.xcm?.availableAssets
            .first(where: { $0.symbol.lowercased() == symbol.lowercased() })?.id else
        {
            throw XcmError.noAvailableXcmAsset(symbol: symbol)
        }

        let remote = try await assetMultilocationFetcher.versionedMultilocation(
            originAssetId: originAssetId,
            destChainId: destChainModel.parentId ?? destChainModel.chainId
        )

        let parents: UInt8
        if let configParents = remote.parents {
            parents = configParents
        } else {
            let goesThroughParent = remote.interiors.isEmpty
                || remote.interiors.contains(where: { $0.isParachain() })
            parents = goesThroughParent ? 1 : 0
        }

        return try XcmV1MultiLocation(
            parents: parents,
            interior: XcmV1MultilocationJunctions(items: remote.interiors.map(Self.v3Junction))
        )
    }

    /// V3 and later name a general key by `length` and 32 bytes of `data`. A key in the V1 form
    /// is converted as XCM converts it: the bytes, zero-padded to 32.
    private static func v3Junction(_ junction: XcmJunction) throws -> XcmJunction {
        switch junction {
        case let .generalKey(key):
            return try .generalKeyV3(generalKey(length: key.count, data: key))
        case let .generalKeyV3(key):
            return try .generalKeyV3(generalKey(length: Int(key.length), data: key.data))
        default:
            return junction
        }
    }

    private static func generalKey(length: Int, data: Data) throws -> GeneralKeyV3 {
        let keyLength = Constants.generalKeyLength
        guard length <= keyLength, data.count <= keyLength, length <= data.count else {
            throw XcmError.unsupportedRemoteXcmVersion
        }

        return GeneralKeyV3(
            lengh: UInt32(length),
            data: data + Data(repeating: 0, count: keyLength - data.count)
        )
    }
}

/// The versions `XcmCallFactory` builds calls in.
private enum SupportedXcmVersion {
    case v3
    case v4
    case v5

    init(_ version: XcmCallFactoryVersion) throws {
        switch version {
        case .V1:
            throw XcmError.unsupportedXcmVersion(version)
        case .V3:
            self = .v3
        case .V4:
            self = .v4
        case .V5:
            self = .v5
        }
    }

    var factoryVersion: XcmCallFactoryVersion {
        switch self {
        case .v3:
            return .V3
        case .v4:
            return .V4
        case .v5:
            return .V5
        }
    }

    func location(parents: UInt8, junctions: [XcmJunction]) throws -> XcmVersionedMultiLocation {
        guard junctions.count <= 8 else {
            throw XcmError.directionNotSupported
        }

        let location = XcmV1MultiLocation(
            parents: parents,
            interior: XcmV1MultilocationJunctions(items: junctions)
        )

        switch self {
        case .v3:
            return .V3(location)
        case .v4:
            return .V4(location)
        case .v5:
            return .V5(location)
        }
    }

    func assets(_ assets: [XcmV1MultiAsset]) -> XcmVersionedMultiAssets {
        switch self {
        case .v3:
            return .V3(assets)
        case .v4:
            return .V4(assets)
        case .v5:
            return .V5(assets)
        }
    }

    func asset(_ asset: XcmV1MultiAsset) -> XcmVersionedMultiAsset {
        switch self {
        case .v3:
            return .V3(asset)
        case .v4:
            return .V4(asset)
        case .v5:
            return .V5(asset)
        }
    }
}

/// Where a chain of the XCM config sits in its relay network. A parachain names its parachain id
/// and its relay chain (`parentId`); a relay chain names neither.
private struct XcmChainPosition {
    let paraId: ParaId?
    let relayChainId: ChainModel.Id

    init(_ chain: ChainModel) throws {
        if let paraIdString = chain.paraId {
            guard let paraId = ParaId(paraIdString), let parentId = chain.parentId else {
                throw XcmError.missingParachainId(chainId: chain.chainId)
            }
            self.paraId = paraId
            relayChainId = parentId
        } else {
            guard chain.parentId == nil else {
                throw XcmError.missingParachainId(chainId: chain.chainId)
            }
            paraId = nil
            relayChainId = chain.chainId
        }
    }

    /// From the relay chain its token is `Here`; from a parachain it is one level up.
    var parentsToRelayChain: UInt8 {
        paraId == nil ? 0 : 1
    }

    var isRelayChainOrSystemParachain: Bool {
        paraId.map { SubstrateConstants.isNativeParachainRange.contains(Int($0)) } ?? true
    }

    /// The junctions of this chain in a location that starts at the relay chain.
    var junctions: [XcmJunction] {
        paraId.map { [XcmJunction.parachain($0)] } ?? []
    }

    /// XCM within a relay network only: a location such as `parents: 1` means a different chain
    /// in another network.
    func checkSameNetwork(as other: XcmChainPosition) throws {
        guard relayChainId == other.relayChainId else {
            throw XcmError.directionNotSupported
        }
    }

    /// The relay chain's token (`Here` of the relay chain) can no longer be sent by reserve
    /// transfer. Assets kept on a parachain, the origin's own included, still can.
    func checkReserveTransferable(_ location: XcmV1MultiLocation) throws {
        if location.parents == parentsToRelayChain, location.interior.items.isEmpty {
            throw XcmError.directionNotSupported
        }
    }
}
