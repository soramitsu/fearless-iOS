import UIKit
import SoraKeystore
import SSFModels

struct CrossChainOriginRoute: Equatable {
    let providerId: String
    let chainAsset: ChainAsset
    let canSign: Bool
    let unavailableReason: String?
    let protocolName: String
    let destinationNames: [String]
    let minimumDisplay: String
    let feeDisplay: String
    let estimatedTimeDisplay: String
    let warnings: [String]
    let reviewedContext: ReviewedCrossChainRouteContext
}

struct ReviewedCrossChainRouteContext: Equatable {
    let routeId: String
    let providerId: String
    let originChainId: ChainModel.Id
    let originAssetId: AssetModel.Id
    let originPrecision: UInt16
    let destinationChainIds: Set<ChainModel.Id>

    init(definition: ReviewedXcmRouteDefinition, providerId: String) {
        routeId = [
            providerId,
            definition.originChainId,
            definition.originAssetId,
            definition.xcmAssetId,
            definition.destinationChainIds.sorted().joined(separator: ","),
            definition.execution.fingerprint
        ].joined(separator: ":")
        self.providerId = providerId
        originChainId = definition.originChainId
        originAssetId = definition.originAssetId
        originPrecision = definition.originPrecision
        destinationChainIds = definition.destinationChainIds
    }

    func validates(origin: ChainAsset, destination: ChainModel? = nil) -> Bool {
        guard origin.chain.chainId == originChainId,
              origin.asset.id == originAssetId,
              origin.asset.precision == originPrecision,
              ReviewedXcmRouteRegistry.definition(for: self)?.execution
              .validates(origin: origin, destination: destination) == true else { return false }
        return destination.map { destinationChainIds.contains($0.chainId) } ?? true
    }
}

protocol CrossChainRouteProvider {
    var identifier: String { get }
    var displayName: String { get }
    var unavailableReason: String { get }
    var reviewedUnavailableRoutes: [ReviewedUnavailableCrossChainRouteDefinition] { get }

    func origins(
        wallet: MetaAccountModel,
        chains: [ChainModel]
    ) -> [CrossChainOriginRoute]
}

struct CrossChainProviderCapability: Equatable {
    let identifier: String
    let displayName: String
    let isAvailable: Bool
    let reason: String?
}

/// Only the exact SORA `bridgeProxy.burn` and Liberland
/// `soraBridgeApp.burn` descriptors below are executable. Other bridge/XCM
/// directions remain explicit unavailable provider states.
enum ReviewedXcmExecutionAuthority {
    static let isAvailable = true
    static let unavailableReason = "No exact reviewed SORA or Liberland bridge call is available for this wallet and current production registry."
}

extension CrossChainRouteProvider {
    var reviewedUnavailableRoutes: [ReviewedUnavailableCrossChainRouteDefinition] { [] }

    func capability(for routes: [CrossChainOriginRoute]) -> CrossChainProviderCapability {
        CrossChainProviderCapability(
            identifier: identifier,
            displayName: displayName,
            isAvailable: !routes.isEmpty,
            reason: routes.isEmpty ? unavailableReason : nil
        )
    }
}

struct ReviewedXcmRouteDefinition: Equatable {
    let originChainId: ChainModel.Id
    /// Canonical asset row in the origin chain catalog.
    let originAssetId: AssetModel.Id
    /// Separately reviewed identity in the bundled XCM registry. This is not
    /// assumed to equal the origin catalog row ID.
    let xcmAssetId: AssetModel.Id
    let originSymbol: String
    let originPrecision: UInt16
    let destinationChainIds: Set<ChainModel.Id>
    let minimumDisplay: String
    let feeDisplay: String
    let estimatedTimeDisplay: String
    let warnings: [String]
    let execution: ReviewedCrossChainExecutionDescriptor
}

enum ReviewedCrossChainSubNetwork: String, Equatable {
    case kusama
    case polkadot
    case liberland
    case soraMainnet
}

enum ReviewedCrossChainRecipientDescriptor: Equatable {
    case relay(accountNetwork: ReviewedCrossChainSubNetwork)
    case parachain(paraId: UInt32, accountNetwork: ReviewedCrossChainSubNetwork)
    case liberland
    case sora

    var fingerprint: String {
        switch self {
        case let .relay(network):
            return "relay-\(network.rawValue)"
        case let .parachain(paraId, network):
            return "parachain-\(paraId)-\(network.rawValue)"
        case .liberland:
            return "liberland"
        case .sora:
            return "sora"
        }
    }
}

enum ReviewedCrossChainRuntimeCall: String, Equatable {
    case soraBridgeProxyBurn
    case liberlandSoraBridgeAppBurn

    var requestedModuleName: String {
        switch self {
        case .soraBridgeProxyBurn: return "bridgeProxy"
        case .liberlandSoraBridgeAppBurn: return "soraBridgeApp"
        }
    }

    var requestedCallName: String { "burn" }
}

enum ReviewedCrossChainRuntimeAssetDescriptor: Equatable {
    case soraAsset(currencyId: String)
    case liberlandAsset(currencyId: String)
    case liberlandNativeLLD

    var fingerprint: String {
        switch self {
        case let .soraAsset(currencyId):
            return "sora:\(currencyId.lowercased())"
        case let .liberlandAsset(currencyId):
            return "liberland-asset:\(currencyId)"
        case .liberlandNativeLLD:
            return "liberland-native-lld"
        }
    }

    func canonicalAssetId(originCatalogId: AssetModel.Id) -> AssetModel.Id {
        switch self {
        case let .soraAsset(currencyId), let .liberlandAsset(currencyId):
            return currencyId
        case .liberlandNativeLLD:
            return originCatalogId
        }
    }

    func validates(_ asset: AssetModel) -> Bool {
        switch self {
        case let .soraAsset(currencyId), let .liberlandAsset(currencyId):
            return asset.currencyId?.caseInsensitiveCompare(currencyId) == .orderedSame
        case .liberlandNativeLLD:
            return asset.currencyId == nil
        }
    }
}

struct ReviewedCrossChainExecutionDescriptor: Equatable {
    let runtimeCall: ReviewedCrossChainRuntimeCall
    let asset: ReviewedCrossChainRuntimeAssetDescriptor
    let destinationChainId: ChainModel.Id
    let network: ReviewedCrossChainSubNetwork
    let recipient: ReviewedCrossChainRecipientDescriptor
    /// Base units of the origin representation. A missing value means that the
    /// reviewed registry currently declares no minimum for this exact asset.
    let minimumAmount: String?

    var fingerprint: String {
        [
            runtimeCall.rawValue,
            asset.fingerprint,
            destinationChainId.lowercased(),
            network.rawValue,
            recipient.fingerprint,
            minimumAmount ?? "none"
        ].joined(separator: "|")
    }

    func validates(origin: ChainAsset, destination: ChainModel?) -> Bool {
        guard asset.validates(origin.asset) else {
            return false
        }
        guard let destination else { return true }
        guard destination.chainId == destinationChainId,
              destination.chainBaseType == .substrate else { return false }

        switch recipient {
        case .relay:
            return destination.paraId == nil
        case let .parachain(paraId, _):
            return destination.paraId.flatMap(UInt32.init) == paraId
        case .liberland:
            return destination.chainId == ReviewedXcmRouteRegistry.liberlandChainId
        case .sora:
            return destination.chainId == ReviewedXcmRouteRegistry.soraChainId
        }
    }
}

enum ReviewedXcmRouteRegistry {
    static let soraChainId = "7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5"
    static let liberlandChainId = "6bd89e052d67a45bb60a9a23e8581053d5e0d619f15cb9865946937e690c42d6"

    static let routes: [ReviewedXcmRouteDefinition] = [
        ReviewedXcmRouteDefinition(
            originChainId: soraChainId,
            originAssetId: "5416b261-a759-4ba6-bc83-ea79a83c5101",
            xcmAssetId: "5416b261-a759-4ba6-bc83-ea79a83c5101",
            originSymbol: "KSM",
            originPrecision: 18,
            destinationChainIds: ["b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"],
            minimumDisplay: "Runtime minimum",
            feeDisplay: "Quoted before confirmation",
            estimatedTimeDisplay: "About 2–10 minutes",
            warnings: ["The destination account must be able to receive KSM."],
            execution: ReviewedCrossChainExecutionDescriptor(
                runtimeCall: .soraBridgeProxyBurn,
                asset: .soraAsset(
                    currencyId: "0x00117b0fa73c4672e03a7d9d774e3b3f91beb893e93d9a8d0430295f44225db8"
                ),
                destinationChainId: "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe",
                network: .kusama,
                recipient: .relay(accountNetwork: .kusama),
                minimumAmount: nil
            )
        ),
        ReviewedXcmRouteDefinition(
            originChainId: soraChainId,
            originAssetId: "cd092a5a-4eb6-4318-9f11-4bf8454d67a2",
            xcmAssetId: "cd092a5a-4eb6-4318-9f11-4bf8454d67a2",
            originSymbol: "DOT",
            originPrecision: 18,
            destinationChainIds: ["91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"],
            minimumDisplay: "1.1 DOT",
            feeDisplay: "Quoted before confirmation",
            estimatedTimeDisplay: "About 2–10 minutes",
            warnings: ["The destination account must be able to receive DOT."],
            execution: ReviewedCrossChainExecutionDescriptor(
                runtimeCall: .soraBridgeProxyBurn,
                asset: .soraAsset(
                    currencyId: "0x0003b1dbee890acfb1b3bc12d1bb3b4295f52755423f84d1751b2545cebf000b"
                ),
                destinationChainId: "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
                network: .polkadot,
                recipient: .relay(accountNetwork: .polkadot),
                minimumAmount: "1100000000000000000"
            )
        ),
        ReviewedXcmRouteDefinition(
            originChainId: soraChainId,
            originAssetId: "fb88fa55-b8c8-4ff1-afa8-f72a86a238a4",
            xcmAssetId: "fb88fa55-b8c8-4ff1-afa8-f72a86a238a4",
            originSymbol: "ACA",
            originPrecision: 18,
            destinationChainIds: ["fc41b9bd8ef8fe53d58c7ea67c794c7ec9a73daf05e6d54b14ff6342c99ba64c"],
            minimumDisplay: "1.1 ACA",
            feeDisplay: "Quoted before confirmation",
            estimatedTimeDisplay: "About 2–10 minutes",
            warnings: ["The destination account must be able to receive ACA."],
            execution: ReviewedCrossChainExecutionDescriptor(
                runtimeCall: .soraBridgeProxyBurn,
                asset: .soraAsset(
                    currencyId: "0x001ddbe1a880031da72f7ea421260bec635fa7d1aa72593d5412795408b6b2ba"
                ),
                destinationChainId: "fc41b9bd8ef8fe53d58c7ea67c794c7ec9a73daf05e6d54b14ff6342c99ba64c",
                network: .polkadot,
                recipient: .parachain(paraId: 2000, accountNetwork: .polkadot),
                minimumAmount: "1100000000000000000"
            )
        ),
        ReviewedXcmRouteDefinition(
            originChainId: soraChainId,
            originAssetId: "b774c386-5cce-454a-a845-1ec0381538ec",
            xcmAssetId: "b774c386-5cce-454a-a845-1ec0381538ec",
            originSymbol: "XOR",
            originPrecision: 18,
            destinationChainIds: [liberlandChainId],
            minimumDisplay: "Runtime minimum",
            feeDisplay: "Quoted before confirmation",
            estimatedTimeDisplay: "About 2–10 minutes",
            warnings: ["Liberland uses 12 decimal places for its representation of XOR."],
            execution: ReviewedCrossChainExecutionDescriptor(
                runtimeCall: .soraBridgeProxyBurn,
                asset: .soraAsset(
                    currencyId: "0x0200000000000000000000000000000000000000000000000000000000000000"
                ),
                destinationChainId: liberlandChainId,
                network: .liberland,
                recipient: .liberland,
                minimumAmount: nil
            )
        ),
        ReviewedXcmRouteDefinition(
            originChainId: soraChainId,
            originAssetId: "0ef3afdc-cdd3-47cc-bd52-817c54ae65b5",
            xcmAssetId: "0ef3afdc-cdd3-47cc-bd52-817c54ae65b5",
            originSymbol: "LLM",
            originPrecision: 18,
            destinationChainIds: [liberlandChainId],
            minimumDisplay: "Runtime minimum",
            feeDisplay: "Quoted before confirmation",
            estimatedTimeDisplay: "About 2–10 minutes",
            warnings: ["Liberland uses 12 decimal places for its representation of LLM."],
            execution: ReviewedCrossChainExecutionDescriptor(
                runtimeCall: .soraBridgeProxyBurn,
                asset: .soraAsset(
                    currencyId: "0x00073edd278e1bd6a7f9d0b27d4f3e93b73c8f0832b58a4df13c69611a99f156"
                ),
                destinationChainId: liberlandChainId,
                network: .liberland,
                recipient: .liberland,
                minimumAmount: nil
            )
        ),
        ReviewedXcmRouteDefinition(
            originChainId: soraChainId,
            originAssetId: "1c3b4fcb-5a5f-4319-9dce-d178006eb9bf",
            xcmAssetId: "a6b83d39-a488-4b34-8352-280705a792ea",
            originSymbol: "LLD",
            originPrecision: 18,
            destinationChainIds: [liberlandChainId],
            minimumDisplay: "1.1 LLD",
            feeDisplay: "Quoted before confirmation",
            estimatedTimeDisplay: "About 2–10 minutes",
            warnings: [
                "Liberland uses 12 decimal places for its representation of LLD.",
                "Locked reviewed identity: the SORA catalog asset ID and Liberland XCM registry ID are different and both must match independently."
            ],
            execution: ReviewedCrossChainExecutionDescriptor(
                runtimeCall: .soraBridgeProxyBurn,
                asset: .soraAsset(
                    currencyId: "0x00513be65493a7fc3e2128d4230061a530acf40478a4affa20bbba27a310673e"
                ),
                destinationChainId: liberlandChainId,
                network: .liberland,
                recipient: .liberland,
                minimumAmount: "1100000000000000000"
            )
        ),
        ReviewedXcmRouteDefinition(
            originChainId: soraChainId,
            originAssetId: "acc32ee0-8fdc-4743-91e1-f70cc4f3069b",
            xcmAssetId: "acc32ee0-8fdc-4743-91e1-f70cc4f3069b",
            originSymbol: "ASTR",
            originPrecision: 18,
            destinationChainIds: ["9eb76c5184c4ab8679d2d5d819fdf90b9c001403e9e17da2e14b6d8aec4029c6"],
            minimumDisplay: "Runtime minimum",
            feeDisplay: "Quoted before confirmation",
            estimatedTimeDisplay: "About 2–10 minutes",
            warnings: ["The destination account must be able to receive ASTR."],
            execution: ReviewedCrossChainExecutionDescriptor(
                runtimeCall: .soraBridgeProxyBurn,
                asset: .soraAsset(
                    currencyId: "0x009dd037fcb32f4fe17c513abd4641a2ece844d106e30788124f0c0acc6e748e"
                ),
                destinationChainId: "9eb76c5184c4ab8679d2d5d819fdf90b9c001403e9e17da2e14b6d8aec4029c6",
                network: .polkadot,
                recipient: .parachain(paraId: 2006, accountNetwork: .polkadot),
                minimumAmount: nil
            )
        ),
        ReviewedXcmRouteDefinition(
            originChainId: liberlandChainId,
            originAssetId: "30b43eb9-36b4-4b40-bf72-330d2e20ee86",
            xcmAssetId: "30b43eb9-36b4-4b40-bf72-330d2e20ee86",
            originSymbol: "LLM",
            originPrecision: 12,
            destinationChainIds: [soraChainId],
            minimumDisplay: "Runtime minimum",
            feeDisplay: "Quoted before confirmation",
            estimatedTimeDisplay: "About 2–10 minutes",
            warnings: ["SORA uses 18 decimal places for its representation of LLM."],
            execution: ReviewedCrossChainExecutionDescriptor(
                runtimeCall: .liberlandSoraBridgeAppBurn,
                asset: .liberlandAsset(currencyId: "1"),
                destinationChainId: soraChainId,
                network: .soraMainnet,
                recipient: .sora,
                minimumAmount: nil
            )
        ),
        ReviewedXcmRouteDefinition(
            originChainId: liberlandChainId,
            originAssetId: "2e7179c9-4308-420e-a654-43c92d119717",
            xcmAssetId: "2e7179c9-4308-420e-a654-43c92d119717",
            originSymbol: "XOR",
            originPrecision: 12,
            destinationChainIds: [soraChainId],
            minimumDisplay: "Runtime minimum",
            feeDisplay: "Quoted before confirmation",
            estimatedTimeDisplay: "About 2–10 minutes",
            warnings: ["SORA uses 18 decimal places for its representation of XOR."],
            execution: ReviewedCrossChainExecutionDescriptor(
                runtimeCall: .liberlandSoraBridgeAppBurn,
                asset: .liberlandAsset(currencyId: "774441749"),
                destinationChainId: soraChainId,
                network: .soraMainnet,
                recipient: .sora,
                minimumAmount: nil
            )
        ),
        ReviewedXcmRouteDefinition(
            originChainId: liberlandChainId,
            originAssetId: "a6b83d39-a488-4b34-8352-280705a792ea",
            xcmAssetId: "a6b83d39-a488-4b34-8352-280705a792e",
            originSymbol: "LLD",
            originPrecision: 12,
            destinationChainIds: [soraChainId],
            minimumDisplay: "1.1 LLD",
            feeDisplay: "Quoted before confirmation",
            estimatedTimeDisplay: "About 2–10 minutes",
            warnings: [
                "SORA uses 18 decimal places for its representation of LLD.",
                "Locked registry warning: the bundled Liberland XCM asset ID does not equal the canonical LLD catalog ID; both exact identities are required."
            ],
            execution: ReviewedCrossChainExecutionDescriptor(
                runtimeCall: .liberlandSoraBridgeAppBurn,
                asset: .liberlandNativeLLD,
                destinationChainId: soraChainId,
                network: .soraMainnet,
                recipient: .sora,
                minimumAmount: "1100000000000"
            )
        )
    ]

    static func definition(for context: ReviewedCrossChainRouteContext) -> ReviewedXcmRouteDefinition? {
        let matches = routes.filter { definition in
            let providerId = definition.originChainId == liberlandChainId ||
                definition.destinationChainIds.contains(liberlandChainId)
                ? "sora-liberland-xcm"
                : "polkaswap-sora-substrate"
            return ReviewedCrossChainRouteContext(
                definition: definition,
                providerId: providerId
            ) == context
        }
        return matches.count == 1 ? matches[0] : nil
    }

    static var soraSubstrateRoutes: [ReviewedXcmRouteDefinition] {
        routes.filter {
            $0.originChainId != liberlandChainId && !$0.destinationChainIds.contains(liberlandChainId)
        }
    }

    static var liberlandRoutes: [ReviewedXcmRouteDefinition] {
        routes.filter {
            $0.originChainId == liberlandChainId || $0.destinationChainIds.contains(liberlandChainId)
        }
    }

    static func validatedOrigin(
        for definition: ReviewedXcmRouteDefinition,
        chainsById: [ChainModel.Id: ChainModel]
    ) -> (ChainAsset, [String])? {
        guard let chain = chainsById[definition.originChainId],
              !chain.isTestnet,
              let xcm = chain.xcm,
              xcm.xcmVersion == .V3 else {
            return nil
        }

        let catalogMatches = chain.chainAssets.filter {
            $0.asset.id == definition.originAssetId &&
                $0.asset.precision == definition.originPrecision &&
                definition.execution.asset.validates($0.asset)
        }
        let runtimeOriginMatches = xcm.availableAssets.filter {
            $0.id == definition.xcmAssetId
        }
        guard catalogMatches.count == 1,
              runtimeOriginMatches.count == 1 else {
            return nil
        }

        let runtimeDestinations = xcm.availableDestinations.filter { destination in
            destination.assets.contains { asset in
                asset.id == definition.xcmAssetId
            }
        }
        guard runtimeDestinations.count == definition.destinationChainIds.count,
              Set(runtimeDestinations.map(\.chainId)) == definition.destinationChainIds else {
            return nil
        }

        let destinationsAreExact = runtimeDestinations.allSatisfy { destination in
            let matchingAssets = destination.assets.filter {
                $0.id == definition.xcmAssetId
            }
            guard matchingAssets.count == 1,
                  let destinationChain = chainsById[destination.chainId] else { return false }
            return definition.execution.validates(
                origin: catalogMatches[0],
                destination: destinationChain
            )
        }
        guard destinationsAreExact else {
            return nil
        }

        let names = definition.destinationChainIds.compactMap { chainsById[$0]?.name }.sorted()
        return (catalogMatches[0], names)
    }
}

private enum ReviewedXcmRouteResolver {
    static func origins(
        providerId: String,
        protocolName: String,
        definitions: [ReviewedXcmRouteDefinition],
        wallet: MetaAccountModel,
        chains: [ChainModel]
    ) -> [CrossChainOriginRoute] {
        let groupedChains = Dictionary(grouping: chains, by: \.chainId)
        guard groupedChains.values.allSatisfy({ $0.count == 1 }) else {
            return []
        }
        let chainsById = groupedChains.mapValues { $0[0] }

        return definitions.compactMap { definition in
            guard let (chainAsset, destinationNames) = ReviewedXcmRouteRegistry.validatedOrigin(
                for: definition,
                chainsById: chainsById
            ),
                let account = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
                return nil
            }

            let accountId = account.isChainAccount ? account.accountId : nil
            let keyTag = chainAsset.chain.isEthereumBased
                ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)
                : KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)
            let canSign = (try? Keychain().checkKey(for: keyTag)) == true

            return CrossChainOriginRoute(
                providerId: providerId,
                chainAsset: chainAsset,
                canSign: canSign,
                unavailableReason: canSign ? nil : NSLocalizedString(
                    "cross_chain.external_signing_unavailable",
                    value: "A local signing key is unavailable. Watch-only and external signing are not supported for this route in this build.",
                    comment: ""
                ),
                protocolName: protocolName,
                destinationNames: destinationNames,
                minimumDisplay: definition.minimumDisplay,
                feeDisplay: definition.feeDisplay,
                estimatedTimeDisplay: definition.estimatedTimeDisplay,
                warnings: definition.warnings,
                reviewedContext: ReviewedCrossChainRouteContext(
                    definition: definition,
                    providerId: providerId
                )
            )
        }
        .sorted {
            ($0.chainAsset.chain.name, $0.chainAsset.asset.symbolUppercased) <
                ($1.chainAsset.chain.name, $1.chainAsset.asset.symbolUppercased)
        }
    }
}

/// Immutable, read-only route authority for directions whose underlying iOS
/// executor cannot yet satisfy the same final identity/balance/fee/minimum
/// guard used by the reviewed SORA burn calls. These definitions are rendered
/// as route rows, but deliberately cannot produce a submission context.
struct ReviewedUnavailableCrossChainRouteDefinition: Equatable {
    let id: String
    let providerId: String
    let originNetworkName: String
    let originChainId: ChainModel.Id
    let originEcosystem: String
    let destinationNetworkName: String
    let destinationChainId: ChainModel.Id
    let destinationEcosystem: String
    let originCatalogAssetId: AssetModel.Id
    let originCanonicalAssetId: AssetModel.Id
    let originRouteAssetId: AssetModel.Id
    let destinationCatalogAssetId: AssetModel.Id?
    let destinationRouteAssetId: AssetModel.Id
    let symbol: String
    let precision: UInt16
    let minimumAmount: String?
    let protocolName: String
    let feeDisplay: String
    let estimatedTimeDisplay: String
    let warnings: [String]
    let unavailableReason: String

    var assetKey: AssetKey {
        AssetKey(
            ecosystem: originEcosystem,
            chainId: originChainId,
            assetId: originCanonicalAssetId
        )
    }

    var minimumDisplay: String {
        minimumAmount.map { "\($0) \(symbol)" } ?? "No fixed minimum; live runtime state required"
    }

    /// Read-only catalog entries cannot be promoted into the transfer flow.
    var isExecutable: Bool { false }
}

enum ReviewedWalletXcmRouteCatalog {
    static let unavailableReason = "Unavailable on iOS: SSFXCM discovers routes, assets and fees by symbol. It cannot bind this exact AssetKey, pallet call, live balances, fees, minimum and remote kill switch into one adjacent final submission guard."

    private enum Chain {
        static let polkadot = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        static let kusama = "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"
        static let polkadotAssetHub = "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f"
        static let kusamaAssetHub = "48239ef607d7928874027a43a67689209727dfb3d3dc5e5b03a39bdc2eda771a"
        static let moonbeam = "fe58ea77779b7abda7da4ec526d14db9b1e9cd40a217c34892af80a9b332b76d"
        static let moonriver = "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"
        static let acala = "fc41b9bd8ef8fe53d58c7ea67c794c7ec9a73daf05e6d54b14ff6342c99ba64c"
        static let karura = "baf5aabe40646d11f0ee8abbdc64f4a4b7674925cba08e4a05ff9ebed6e2126b"
        static let parallel = "e61a41c53f5dcd0beb09df93b34402aada44cb05117b71059cce40a2723a4e97"
        static let bifrost = "9f28c6a68e0fc9646eff64935684f6eeeece527e37bbe1f213d22caa1d9d6bed"
    }

    private static let dotXcmAssetId = "99e66d4f-00cd-4d73-bd1b-3adadcacffb2"
    private static let ksmXcmAssetId = "0ceffe96-8090-404e-815c-91118ee5dd65"

    static let routes: [ReviewedUnavailableCrossChainRouteDefinition] = [
        walletRoute(
            origin: ("Polkadot", Chain.polkadot, "substrate"),
            destination: ("Polkadot Asset Hub", Chain.polkadotAssetHub, "substrate"),
            catalogAssetId: "887a17c7-1370-4de0-97dd-5422e294fa75",
            canonicalAssetId: "887a17c7-1370-4de0-97dd-5422e294fa75",
            symbol: "DOT",
            precision: 10
        ),
        walletRoute(
            origin: ("Polkadot", Chain.polkadot, "substrate"),
            destination: ("Moonbeam", Chain.moonbeam, "evm"),
            catalogAssetId: "887a17c7-1370-4de0-97dd-5422e294fa75",
            canonicalAssetId: "887a17c7-1370-4de0-97dd-5422e294fa75",
            symbol: "DOT",
            precision: 10
        ),
        walletRoute(
            origin: ("Polkadot", Chain.polkadot, "substrate"),
            destination: ("Acala", Chain.acala, "substrate"),
            catalogAssetId: "887a17c7-1370-4de0-97dd-5422e294fa75",
            canonicalAssetId: "887a17c7-1370-4de0-97dd-5422e294fa75",
            symbol: "DOT",
            precision: 10
        ),
        walletRoute(
            origin: ("Polkadot", Chain.polkadot, "substrate"),
            destination: ("Parallel", Chain.parallel, "substrate"),
            catalogAssetId: "887a17c7-1370-4de0-97dd-5422e294fa75",
            canonicalAssetId: "887a17c7-1370-4de0-97dd-5422e294fa75",
            symbol: "DOT",
            precision: 10
        ),
        walletRoute(
            origin: ("Kusama", Chain.kusama, "substrate"),
            destination: ("Kusama Asset Hub", Chain.kusamaAssetHub, "substrate"),
            catalogAssetId: "1e0c2ec6-935f-49bd-a854-5e12ee6c9f1b",
            canonicalAssetId: "1e0c2ec6-935f-49bd-a854-5e12ee6c9f1b",
            symbol: "KSM",
            precision: 12
        ),
        walletRoute(
            origin: ("Kusama", Chain.kusama, "substrate"),
            destination: ("Moonriver", Chain.moonriver, "evm"),
            catalogAssetId: "1e0c2ec6-935f-49bd-a854-5e12ee6c9f1b",
            canonicalAssetId: "1e0c2ec6-935f-49bd-a854-5e12ee6c9f1b",
            symbol: "KSM",
            precision: 12
        ),
        walletRoute(
            origin: ("Kusama", Chain.kusama, "substrate"),
            destination: ("Karura", Chain.karura, "substrate"),
            catalogAssetId: "1e0c2ec6-935f-49bd-a854-5e12ee6c9f1b",
            canonicalAssetId: "1e0c2ec6-935f-49bd-a854-5e12ee6c9f1b",
            symbol: "KSM",
            precision: 12
        ),
        walletRoute(
            origin: ("Polkadot Asset Hub", Chain.polkadotAssetHub, "substrate"),
            destination: ("Polkadot", Chain.polkadot, "substrate"),
            catalogAssetId: "887a17c7-1370-4de0-97dd-5422e294fa75",
            canonicalAssetId: "887a17c7-1370-4de0-97dd-5422e294fa75",
            symbol: "DOT",
            precision: 10
        ),
        walletRoute(
            origin: ("Acala", Chain.acala, "substrate"),
            destination: ("Polkadot", Chain.polkadot, "substrate"),
            catalogAssetId: "ed98bee1-34ce-4aa2-896e-508380dea1c2",
            canonicalAssetId: "ed98bee1-34ce-4aa2-896e-508380dea1c2",
            symbol: "DOT",
            precision: 10
        ),
        walletRoute(
            origin: ("Parallel", Chain.parallel, "substrate"),
            destination: ("Polkadot", Chain.polkadot, "substrate"),
            catalogAssetId: "769ffb89-fd2f-4add-94a1-d2f9f716c143",
            canonicalAssetId: "101",
            symbol: "DOT",
            precision: 10
        ),
        walletRoute(
            origin: ("Moonbeam", Chain.moonbeam, "evm"),
            destination: ("Polkadot", Chain.polkadot, "substrate"),
            catalogAssetId: "7e4e064e-2b23-4eb5-96db-e6491c4031e5",
            canonicalAssetId: "42259045809535163221576417993425387648",
            symbol: "DOT",
            precision: 10
        ),
        walletRoute(
            origin: ("Kusama Asset Hub", Chain.kusamaAssetHub, "substrate"),
            destination: ("Kusama", Chain.kusama, "substrate"),
            catalogAssetId: "1e0c2ec6-935f-49bd-a854-5e12ee6c9f1b",
            canonicalAssetId: "1e0c2ec6-935f-49bd-a854-5e12ee6c9f1b",
            symbol: "KSM",
            precision: 12
        ),
        walletRoute(
            origin: ("Karura", Chain.karura, "substrate"),
            destination: ("Kusama", Chain.kusama, "substrate"),
            catalogAssetId: "223b0282-b5c9-48ed-87e3-5e9ef6714ac8",
            canonicalAssetId: "223b0282-b5c9-48ed-87e3-5e9ef6714ac8",
            symbol: "KSM",
            precision: 12
        ),
        walletRoute(
            origin: ("Moonriver", Chain.moonriver, "evm"),
            destination: ("Kusama", Chain.kusama, "substrate"),
            catalogAssetId: "980af72c-d1b8-46c7-9793-fa87912652ec",
            canonicalAssetId: "42259045809535163221576417993425387648",
            symbol: "KSM",
            precision: 12
        ),
        walletRoute(
            origin: ("Bifrost Kusama", Chain.bifrost, "substrate"),
            destination: ("Kusama", Chain.kusama, "substrate"),
            catalogAssetId: "922c191c-4cb8-407e-8b81-2cfc52170c3b",
            canonicalAssetId: "922c191c-4cb8-407e-8b81-2cfc52170c3b",
            symbol: "KSM",
            precision: 12
        )
    ]

    private static func walletRoute(
        origin: (name: String, chainId: ChainModel.Id, ecosystem: String),
        destination: (name: String, chainId: ChainModel.Id, ecosystem: String),
        catalogAssetId: AssetModel.Id,
        canonicalAssetId: AssetModel.Id,
        symbol: String,
        precision: UInt16
    ) -> ReviewedUnavailableCrossChainRouteDefinition {
        let routeAssetId = symbol == "DOT" ? dotXcmAssetId : ksmXcmAssetId
        return ReviewedUnavailableCrossChainRouteDefinition(
            id: [
                "unavailable-v1",
                "wallet-xcm",
                origin.chainId,
                destination.chainId,
                catalogAssetId
            ].joined(separator: ":"),
            providerId: "wallet-xcm",
            originNetworkName: origin.name,
            originChainId: origin.chainId,
            originEcosystem: origin.ecosystem,
            destinationNetworkName: destination.name,
            destinationChainId: destination.chainId,
            destinationEcosystem: destination.ecosystem,
            originCatalogAssetId: catalogAssetId,
            originCanonicalAssetId: canonicalAssetId,
            originRouteAssetId: routeAssetId,
            destinationCatalogAssetId: nil,
            destinationRouteAssetId: routeAssetId,
            symbol: symbol,
            precision: precision,
            minimumAmount: nil,
            protocolName: "Polkadot XCM v3",
            feeDisplay: "Live origin and destination fees unavailable while execution is blocked",
            estimatedTimeDisplay: "About 2–10 minutes when reviewed execution is enabled",
            warnings: [
                "Catalog, canonical AssetKey and XCM identities must each match exactly.",
                "No funds are submitted while this route remains unavailable."
            ],
            unavailableReason: unavailableReason
        )
    }
}

enum ReviewedSoraEvmRouteCatalog {
    static let routes: [ReviewedUnavailableCrossChainRouteDefinition] = [
        ReviewedUnavailableCrossChainRouteDefinition(
            id: "unavailable-v1:polkaswap-sora-evm:7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5:1:82f45df3-b6d8-43e7-a440-c0e73ab59785",
            providerId: "polkaswap-sora-evm",
            originNetworkName: "SORA Mainnet",
            originChainId: ReviewedXcmRouteRegistry.soraChainId,
            originEcosystem: "substrate",
            destinationNetworkName: "Ethereum Mainnet",
            destinationChainId: "1",
            destinationEcosystem: "evm",
            originCatalogAssetId: "82f45df3-b6d8-43e7-a440-c0e73ab59785",
            originCanonicalAssetId: "0x0200070000000000000000000000000000000000000000000000000000000000",
            originRouteAssetId: "82f45df3-b6d8-43e7-a440-c0e73ab59785",
            destinationCatalogAssetId: "c2a6c062-d511-4bde-9ce6-ea775d2a302c",
            destinationRouteAssetId: "c2a6c062-d511-4bde-9ce6-ea775d2a302c",
            symbol: "ETH",
            precision: 18,
            minimumAmount: nil,
            protocolName: "SORA ↔ Ethereum legacy bridge",
            feeDisplay: "Multi-step fees cannot be quoted safely in this release",
            estimatedTimeDisplay: "About 10–60 minutes plus claim",
            warnings: ["No funds are submitted while this capability is unavailable."],
            unavailableReason: "Ethereum delivery requires a second claim transaction and recovery tracking. This route stays unavailable until that full flow is reviewed."
        ),
        ReviewedUnavailableCrossChainRouteDefinition(
            id: "unavailable-v1:polkaswap-sora-evm:1:7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5:c2a6c062-d511-4bde-9ce6-ea775d2a302c",
            providerId: "polkaswap-sora-evm",
            originNetworkName: "Ethereum Mainnet",
            originChainId: "1",
            originEcosystem: "evm",
            destinationNetworkName: "SORA Mainnet",
            destinationChainId: ReviewedXcmRouteRegistry.soraChainId,
            destinationEcosystem: "substrate",
            originCatalogAssetId: "c2a6c062-d511-4bde-9ce6-ea775d2a302c",
            originCanonicalAssetId: "c2a6c062-d511-4bde-9ce6-ea775d2a302c",
            originRouteAssetId: "c2a6c062-d511-4bde-9ce6-ea775d2a302c",
            destinationCatalogAssetId: "82f45df3-b6d8-43e7-a440-c0e73ab59785",
            destinationRouteAssetId: "82f45df3-b6d8-43e7-a440-c0e73ab59785",
            symbol: "ETH",
            precision: 18,
            minimumAmount: nil,
            protocolName: "SORA ↔ Ethereum legacy bridge",
            feeDisplay: "Multi-step gas, allowance and bridge fees cannot be quoted safely in this release",
            estimatedTimeDisplay: "About 10–60 minutes plus claim",
            warnings: ["No funds are submitted while this capability is unavailable."],
            unavailableReason: "Ethereum → SORA requires a contract transaction, live gas and allowance checks, and recovery tracking. This route stays unavailable until that full flow is reviewed."
        )
    ]
}

enum ReviewedUnavailableCrossChainRouteCatalog {
    static let routes = ReviewedWalletXcmRouteCatalog.routes + ReviewedSoraEvmRouteCatalog.routes
}

struct WalletXcmRouteProvider: CrossChainRouteProvider {
    let identifier = "wallet-xcm"
    let displayName = "Wallet XCM"
    let unavailableReason = ReviewedWalletXcmRouteCatalog.unavailableReason
    let reviewedUnavailableRoutes = ReviewedWalletXcmRouteCatalog.routes

    func origins(
        wallet _: MetaAccountModel,
        chains _: [ChainModel]
    ) -> [CrossChainOriginRoute] {
        []
    }
}

struct SoraSubstrateBridgeRouteProvider: CrossChainRouteProvider {
    let identifier = "polkaswap-sora-substrate"
    let displayName = "Polkaswap SORA ↔ Substrate"
    let unavailableReason = "No reviewed SORA bridgeProxy.burn route is available for this wallet and current production registry. Add a local SORA account or refresh network metadata."

    func origins(wallet: MetaAccountModel, chains: [ChainModel]) -> [CrossChainOriginRoute] {
        ReviewedXcmRouteResolver.origins(
            providerId: identifier,
            protocolName: "SORA bridge · XCM v3",
            definitions: ReviewedXcmRouteRegistry.soraSubstrateRoutes,
            wallet: wallet,
            chains: chains
        )
    }
}

struct LiberlandXcmRouteProvider: CrossChainRouteProvider {
    let identifier = "sora-liberland-xcm"
    let displayName = "SORA ↔ Liberland"
    let unavailableReason = "No reviewed SORA ↔ Liberland burn route is available for this wallet and current production registry. Add a local account or refresh network metadata."

    func origins(wallet: MetaAccountModel, chains: [ChainModel]) -> [CrossChainOriginRoute] {
        ReviewedXcmRouteResolver.origins(
            providerId: identifier,
            protocolName: "Liberland bridge · XCM v3",
            definitions: ReviewedXcmRouteRegistry.liberlandRoutes,
            wallet: wallet,
            chains: chains
        )
    }
}

struct PolkaswapEvmBridgeRouteProvider: CrossChainRouteProvider {
    let identifier = "polkaswap-sora-evm"
    let displayName = "Polkaswap SORA ↔ EVM"
    let unavailableReason = "The current iOS Polkaswap flow has no reviewed executable SORA ↔ EVM bridge adapter. Quotes and submissions stay disabled until one is approved."
    let reviewedUnavailableRoutes = ReviewedSoraEvmRouteCatalog.routes

    func origins(wallet _: MetaAccountModel, chains _: [ChainModel]) -> [CrossChainOriginRoute] {
        []
    }
}

enum CrossChainProviderRegistry {
    static var defaultProviders: [CrossChainRouteProvider] {
        [
            WalletXcmRouteProvider(),
            SoraSubstrateBridgeRouteProvider(),
            LiberlandXcmRouteProvider(),
            PolkaswapEvmBridgeRouteProvider()
        ]
    }
}

final class CrossChainRootViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case routes
        case providers

        var title: String {
            switch self {
            case .routes:
                return "Choose origin"
            case .providers:
                return "Provider coverage"
            }
        }
    }

    private let wallet: MetaAccountModel
    private let providers: [CrossChainRouteProvider]
    private let unavailableRouteInventory: [ReviewedUnavailableCrossChainRouteDefinition]
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var origins: [CrossChainOriginRoute] = []
    private var capabilities: [CrossChainProviderCapability] = []

    init(
        wallet: MetaAccountModel,
        providers: [CrossChainRouteProvider] = CrossChainProviderRegistry.defaultProviders,
        unavailableRouteInventory: [ReviewedUnavailableCrossChainRouteDefinition]? = nil
    ) {
        self.wallet = wallet
        self.providers = providers
        self.unavailableRouteInventory = unavailableRouteInventory ?? providers.flatMap {
            $0.reviewedUnavailableRoutes
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tab.cross_chain", value: "Cross-chain", comment: "")
        view.backgroundColor = R.color.colorBlack19()
        configureTableView()
        reloadRoutes()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        reloadRoutes()
    }

    private func configureTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorColor = R.color.colorBlurSeparator()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CrossChainOriginCell")

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func reloadRoutes() {
        let chains = ChainRegistryFacade.sharedRegistry.availableChains
        let evaluations = providers.map { provider -> ([CrossChainOriginRoute], CrossChainProviderCapability) in
            let routes = provider.origins(wallet: wallet, chains: chains)
            return (routes, provider.capability(for: routes))
        }
        origins = evaluations.flatMap(\.0)
        capabilities = evaluations.map(\.1)
        tableView.reloadData()
    }

    private func open(_ route: CrossChainOriginRoute) {
        guard MultiChainFeaturePolicy.current.crossChainMutationsEnabled else {
            presentMessage(
                title: NSLocalizedString("cross_chain.actions_paused", value: "Cross-chain actions paused", comment: ""),
                message: NSLocalizedString(
                    "cross_chain.actions_paused_message",
                    value: "Reviewed routes remain visible, but transfers are temporarily disabled by the remote safety switch.",
                    comment: ""
                )
            )
            return
        }

        guard route.canSign else {
            presentMessage(
                title: NSLocalizedString("cross_chain.route_unavailable", value: "Route unavailable", comment: ""),
                message: route.unavailableReason ?? NSLocalizedString(
                    "cross_chain.cannot_sign",
                    value: "This wallet cannot sign transactions for the selected origin.",
                    comment: ""
                )
            )
            return
        }

        guard let module = CrossChainAssembly.configureModule(
            with: route.chainAsset,
            wallet: wallet,
            reviewedRoute: route.reviewedContext
        ) else {
            presentMessage(
                title: NSLocalizedString("cross_chain.no_route", value: "No supported route", comment: ""),
                message: String(
                    format: NSLocalizedString(
                        "cross_chain.no_reviewed_route",
                        value: "A reviewed route could not be created for %@ and %@.",
                        comment: ""
                    ),
                    route.chainAsset.chain.name,
                    route.chainAsset.asset.symbolUppercased
                )
            )
            return
        }

        module.view.controller.hidesBottomBarWhenPushed = false
        navigationController?.pushViewController(module.view.controller, animated: true)
    }

    private func presentMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension CrossChainRootViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .routes:
            return max(origins.count + unavailableRouteInventory.count, 1)
        case .providers:
            return capabilities.count + 1
        case .none:
            return 0
        }
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CrossChainOriginCell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        configuration.textProperties.color = R.color.colorWhite() ?? .white
        configuration.textProperties.numberOfLines = 2
        configuration.secondaryTextProperties.color = R.color.colorLightGray() ?? .lightGray
        configuration.secondaryTextProperties.numberOfLines = 0
        cell.backgroundColor = R.color.colorWhite8()

        switch Section(rawValue: indexPath.section) {
        case .routes:
            if let route = origins[safe: indexPath.row] {
                configuration.text = "\(route.chainAsset.chain.name) → \(route.destinationNames.joined(separator: ", ")) · \(route.chainAsset.asset.symbolUppercased)"
                configuration.secondaryText = route.unavailableReason ?? [
                    route.protocolName,
                    "AssetKey: \(route.chainAsset.assetKey.assetId)",
                    "minimum: \(route.minimumDisplay)",
                    "fees: \(route.feeDisplay)",
                    route.estimatedTimeDisplay,
                    route.warnings.first
                ].compactMap { $0 }.joined(separator: " · ")
                configuration.image = R.image.crossChainIcon()
                cell.accessoryType = route.canSign ? .disclosureIndicator : .none
                cell.selectionStyle = .default
                break
            }

            let unavailableIndex = indexPath.row - origins.count
            guard let route = unavailableRouteInventory[safe: unavailableIndex] else {
                configuration.text = "No XCM origins available"
                configuration.secondaryText = ReviewedXcmExecutionAuthority.unavailableReason
                configuration.image = UIImage(systemName: "arrow.triangle.branch")
                cell.accessoryType = .none
                cell.selectionStyle = .none
                cell.contentConfiguration = configuration
                return cell
            }

            configuration.text = "\(route.originNetworkName) → \(route.destinationNetworkName) · \(route.symbol)"
            configuration.secondaryText = [
                route.protocolName,
                "AssetKey: \(route.assetKey.assetId)",
                "route asset: \(route.originRouteAssetId)",
                "minimum: \(route.minimumDisplay)",
                "fees: \(route.feeDisplay)",
                route.estimatedTimeDisplay,
                route.unavailableReason,
                route.warnings.first
            ].compactMap { $0 }.joined(separator: " · ")
            configuration.image = UIImage(systemName: "lock.shield")
            cell.accessoryType = .none
            cell.selectionStyle = .none
        case .providers:
            if let capability = capabilities[safe: indexPath.row] {
                configuration.text = capability.displayName
                configuration.secondaryText = capability.isAvailable
                    ? "Reviewed route available"
                    : capability.reason
                configuration.image = UIImage(systemName: capability.isAvailable ? "checkmark.shield" : "xmark.shield")
            } else {
                configuration.text = "Other ecosystems"
                configuration.secondaryText = "TON, Bitcoin, Solana, Iroha and unsupported EVM routes remain unavailable until a reviewed provider is added."
                configuration.image = UIImage(systemName: "info.circle")
            }
            cell.accessoryType = .none
            cell.selectionStyle = .none
        case .none:
            break
        }

        cell.contentConfiguration = configuration
        return cell
    }
}

extension CrossChainRootViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .routes,
              let route = origins[safe: indexPath.row] else {
            return
        }

        open(route)
    }
}
