import Foundation
import SSFModels

// Backward-compatibility APIs for older call sites still constructing
// AssetModel with the previous, expanded initializer and properties.

public extension AssetModel {
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
            priceId: nil,
            coingeckoPriceId: coingeckoPriceId,
            priceProvider: priceProvider
        )
    }

    // Minimal shims for removed fields used in some mappers.
    var existentialDeposit: String? { nil }
    var isNative: Bool { tokenProperties?.isNative ?? false }
    var type: SubstrateAssetType? { substrateType ?? tokenProperties?.type }
    var staking: RawStakingType? { tokenProperties?.stacking.flatMap { RawStakingType(rawValue: $0) } }
    var purchaseProviders: [PurchaseProvider]? { nil }
    var priceData: [PriceData] { [] }

    // Legacy convenience used throughout presenters; return nil when not available
    func getPrice(for _: Any) -> PriceData? { nil }
}

// Allow using AssetModel with Repository/CoreData APIs expecting RobinHood.Identifiable
extension AssetModel: RobinHood.Identifiable {
    public var identifier: String { id }
}

// Newer storage/repository constraints require Swift.Identifiable.
extension AssetModel: Swift.Identifiable {}
