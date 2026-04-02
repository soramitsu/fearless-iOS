import Foundation
import SSFModels

// MARK: - AssetModel compatibility

public extension AssetModel {
    // Backward initializer used by legacy mappers
    init(
        id: String,
        name: String,
        symbol: String,
        precision: UInt16,
        icon: URL?,
        currencyId: String?,
        existentialDeposit: String?,
        color: String?,
        isUtility: Bool,
        isNative: Bool,
        staking: RawStakingType?,
        purchaseProviders: [PurchaseProvider]?,
        type: SubstrateAssetType?,
        ethereumType: EthereumAssetType?,
        priceProvider: PriceProvider?,
        coingeckoPriceId: String?,
        priceData: [PriceData]
    ) {
        let resolvedAssetType: ChainAssetType
        if let ethereumType {
            resolvedAssetType = .ethereum(ethereumType: ethereumType)
        } else {
            resolvedAssetType = .substrate(substrateType: type ?? .normal)
        }

        self.init(
            id: id,
            name: name,
            symbol: symbol,
            precision: precision,
            icon: icon,
            currencyId: currencyId,
            existentialDeposit: existentialDeposit,
            color: color,
            isUtility: isUtility,
            isNative: isNative,
            staking: staking,
            purchaseProviders: purchaseProviders,
            assetType: resolvedAssetType,
            priceProvider: priceProvider,
            coingeckoPriceId: coingeckoPriceId,
            priceData: priceData
        )
    }

    var ethereumType: EthereumAssetType? {
        // B.E.B.I </3
        switch assetType {
        case let .ethereum(ethereumType):
            return ethereumType
        default:
            return nil
        }
    }

    var substrateType: SubstrateAssetType? {
        switch assetType {
        case let .substrate(substrateType):
            return substrateType
        default:
            return nil
        }
    }
}

// MARK: - External API compatibility

public extension ChainModel.BlockExplorer {
    init?(type: String, url: URL, apiKey _: String?) {
        self.init(type: type, url: url)
    }
}

// MARK: - XCM compatibility

public extension XcmAvailableAsset {
    init(id: String, symbol: String, minAmount: Decimal?) {
        let stringValue = minAmount.map { NSDecimalNumber(decimal: $0).stringValue }
        self.init(id: id, symbol: symbol, minAmount: stringValue)
    }
}

// MARK: - ChainModel compatibility

public extension ChainModel {
    convenience init(
        rank: UInt16?,
        disabled: Bool,
        chainId: Id,
        parentId: Id? = nil,
        paraId: String?,
        name: String,
        xcm: XcmChain?,
        nodes: Set<ChainNodeModel>,
        addressPrefix: UInt16,
        types: TypesSettings? = nil,
        icon: URL?,
        options: [ChainOptions]? = nil,
        externalApi: ExternalApiSet? = nil,
        selectedNode: ChainNodeModel? = nil,
        customNodes: Set<ChainNodeModel>? = nil,
        iosMinAppVersion: String?,
        identityChain _: String?
    ) {
        self.init(
            ecosystem: .substrate,
            rank: rank,
            disabled: disabled,
            chainId: chainId,
            parentId: parentId,
            paraId: paraId,
            name: name,
            assets: [],
            xcm: xcm,
            nodes: nodes,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApi: externalApi,
            selectedNode: selectedNode,
            customNodes: customNodes,
            iosMinAppVersion: iosMinAppVersion,
            identityChain: nil,
            tonBridgeUrl: nil
        )
    }

    /// Legacy helper that used to live inside the locally-defined ChainModel.
    /// Some subsystems (account fetching, subscriptions, transfers) still gate behavior on this flag,
    /// so keep providing the same surface on top of the SSFModels definition.
    var isEthereum: Bool {
        ecosystem == .ethereum || options?.contains(.ethereum) == true
    }
}

// MARK: - Meta account compatibility

extension ChainAccountRequest {
    var isEthereumBased: Bool {
        ecosystem == .ethereum || ecosystem == .ethereumBased
    }
}

// MARK: - Polkadot runtime compatibility

enum PolkadotRuntimeCompatibility {
    enum BlockProviderHint {
        case relay
        case local
    }

    enum Pallet {
        case vesting
        case multisig
        case proxy
        case nfts
    }

    /// Known Asset Hub paraIds by ecosystem (dot/kusama/westend use `1000` conventions).
    private static let assetHubParaIds: Set<String> = ["1000"]

    static func blockProviderHint(for pallet: Pallet, on chain: ChainModel) -> BlockProviderHint? {
        guard isTrustedAliaser(chain: chain) else {
            return nil
        }

        switch pallet {
        case .vesting: return .relay
        case .multisig: return .local
        case .proxy: return .relay
        case .nfts: return .relay
        }
    }

    static func isTrustedAliaser(chain: ChainModel) -> Bool {
        guard let paraId = chain.paraId else {
            return false
        }

        return assetHubParaIds.contains(paraId)
    }
}
