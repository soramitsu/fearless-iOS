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
        existentialDeposit _: String?,
        color: String?,
        isUtility: Bool,
        isNative: Bool,
        staking: RawStakingType?,
        purchaseProviders _: [PurchaseProvider]?,
        type: SubstrateAssetType?,
        ethereumType: EthereumAssetType?,
        priceProvider: PriceProvider?,
        coingeckoPriceId: String?,
        priceData _: [PriceData]
    ) {
        let tokenProps = TokenProperties(
            priceId: coingeckoPriceId,
            currencyId: currencyId,
            color: color,
            type: type,
            isNative: isNative,
            stacking: staking?.rawValue
        )

        self.init(
            id: id,
            name: name,
            symbol: symbol,
            isUtility: isUtility,
            precision: precision,
            icon: icon,
            substrateType: type,
            ethereumType: ethereumType,
            tokenProperties: tokenProps,
            price: nil,
            priceId: coingeckoPriceId,
            coingeckoPriceId: coingeckoPriceId,
            priceProvider: priceProvider
        )
    }

    // Legacy fields accessors
    var existentialDeposit: String? { nil }
    var staking: RawStakingType? { tokenProperties?.stacking.flatMap { RawStakingType(rawValue: $0) } }
    var isNative: Bool { tokenProperties?.isNative ?? false }
    var purchaseProviders: [PurchaseProvider]? { nil }
    func getPrice(for _: Currency) -> PriceData? { nil }
}

// MARK: - External API compatibility

public extension ChainModel.BlockExplorer {
    init?(type: String, url: URL) {
        self.init(type: type, url: url, apiKey: nil)
    }
}

public extension ChainModel.ExternalApiSet {
    init(
        staking: ChainModel.BlockExplorer? = nil,
        history: ChainModel.BlockExplorer? = nil,
        crowdloans: ChainModel.ExternalResource? = nil,
        explorers: [ChainModel.ExternalApiExplorer]? = nil,
        pricing _: ChainModel.BlockExplorer?
    ) {
        self.init(staking: staking, history: history, crowdloans: crowdloans, explorers: explorers)
    }
}

// MARK: - XCM compatibility

public extension XcmAvailableAsset {
    init(id: String, symbol: String, minAmount _: Decimal?) {
        self.init(id: id, symbol: symbol)
    }
}

// MARK: - ChainModel compatibility

public extension ChainModel {
    // Legacy initializer without tokens/properties
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
        let tokens = ChainRemoteTokens(type: .config, whitelist: nil, utilityId: nil, tokens: [])
        let properties = ChainProperties(addressPrefix: String(addressPrefix))
        self.init(
            rank: rank,
            disabled: disabled,
            chainId: chainId,
            parentId: parentId,
            paraId: paraId,
            name: name,
            tokens: tokens,
            xcm: xcm,
            nodes: nodes,
            types: types,
            icon: icon,
            options: options,
            externalApi: externalApi,
            selectedNode: selectedNode,
            customNodes: customNodes,
            iosMinAppVersion: iosMinAppVersion,
            properties: properties
        )
    }

    // Legacy fields
    var addressPrefix: UInt16 { UInt16(properties.addressPrefix) ?? 0 }
    var identityChain: String? { nil }
}
