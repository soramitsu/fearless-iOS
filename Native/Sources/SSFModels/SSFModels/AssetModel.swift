import Foundation

public struct AssetModel: Equatable, Codable, Hashable {
    public typealias Id = String
    public typealias PriceId = String

    public let id: String
    public let name: String
    public let symbol: String
    public let precision: UInt16
    public let icon: URL?
    public let price: Decimal?
    public let fiatDayChange: Decimal?
    public let currencyId: String?
    public let existentialDeposit: String?
    public let color: String?
    public let isUtility: Bool
    public let isNative: Bool
    public let staking: RawStakingType?
    public let purchaseProviders: [PurchaseProvider]?
    public let type: SubstrateAssetType?
    public let ethereumType: EthereumAssetType?
    public let priceProvider: PriceProvider?

    public let coingeckoPriceId: PriceId?
    public var priceId: PriceId? {
        if let priceProvider = priceProvider {
            return priceProvider.id
        }
        
        return coingeckoPriceId
    }

    public var symbolUppercased: String {
        symbol.uppercased()
    }

    public init(
        id: String,
        name: String,
        symbol: String,
        precision: UInt16,
        icon: URL? = nil,
        price: Decimal? = nil,
        fiatDayChange: Decimal? = nil,
        currencyId: String? = nil,
        existentialDeposit: String? = nil,
        color: String? = nil,
        isUtility: Bool,
        isNative: Bool,
        staking: RawStakingType? = nil,
        purchaseProviders: [PurchaseProvider]? = nil,
        type: SubstrateAssetType? = nil,
        ethereumType: EthereumAssetType? = nil,
        priceProvider: PriceProvider? = nil,
        coingeckoPriceId: PriceId? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.precision = precision
        self.icon = icon
        self.price = price
        self.fiatDayChange = fiatDayChange
        self.currencyId = currencyId
        self.existentialDeposit = existentialDeposit
        self.color = color
        self.isUtility = isUtility
        self.isNative = isNative
        self.staking = staking
        self.purchaseProviders = purchaseProviders
        self.type = type
        self.ethereumType = ethereumType
        self.priceProvider = priceProvider
        self.coingeckoPriceId = coingeckoPriceId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        precision = try container.decode(UInt16.self, forKey: .precision)
        icon = try? container.decode(URL?.self, forKey: .icon)
        currencyId = try? container.decode(String?.self, forKey: .currencyId)
        existentialDeposit = try? container.decode(String?.self, forKey: .existentialDeposit)
        color = try? container.decode(String.self, forKey: .color)
        isUtility = (try? container.decode(Bool?.self, forKey: .isUtility)) ?? false
        isNative = (try? container.decode(Bool?.self, forKey: .isNative)) ?? false
        staking = try? container.decode(RawStakingType.self, forKey: .staking)
        purchaseProviders = try? container.decode(
            [PurchaseProvider]?.self,
            forKey: .purchaseProviders
        )
        type = try? container.decode(SubstrateAssetType?.self, forKey: .type)
        ethereumType = try? container.decode(EthereumAssetType?.self, forKey: .ethereumType)

        coingeckoPriceId = try? container.decode(String?.self, forKey: .priceId)
        priceProvider = try container.decodeIfPresent(PriceProvider.self, forKey: .priceProvider)

        price = nil
        fiatDayChange = nil
    }

    public func encode(to _: Encoder) throws {}

    public func replacingPrice(_ priceData: PriceData) -> AssetModel {
        AssetModel(
            id: id,
            name: name,
            symbol: symbol,
            precision: precision,
            icon: icon,
            price: Decimal(string: priceData.price),
            fiatDayChange: priceData.fiatDayChange,
            currencyId: currencyId,
            existentialDeposit: existentialDeposit,
            color: color,
            isUtility: isUtility,
            isNative: isNative,
            staking: staking,
            purchaseProviders: purchaseProviders,
            type: type,
            ethereumType: ethereumType,
            priceProvider: priceProvider,
            coingeckoPriceId: coingeckoPriceId
        )
    }

    public static func == (lhs: AssetModel, rhs: AssetModel) -> Bool {
        lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.precision == rhs.precision &&
            lhs.icon == rhs.icon &&
            lhs.symbol == rhs.symbol &&
            lhs.currencyId == rhs.currencyId &&
            lhs.existentialDeposit == rhs.existentialDeposit &&
            lhs.color == rhs.color &&
            lhs.isUtility == rhs.isUtility &&
            lhs.isNative == rhs.isNative &&
            lhs.staking == rhs.staking &&
            lhs.purchaseProviders == rhs.purchaseProviders &&
            lhs.type == rhs.type &&
            lhs.ethereumType == rhs.ethereumType &&
            lhs.priceProvider == rhs.priceProvider
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension AssetModel {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbol
        case icon
        case priceId
        case currencyId
        case existentialDeposit
        case color
        case isUtility
        case isNative
        case staking
        case purchaseProviders
        case type
        case ethereumType
        case priceProvider
        case precision
    }
}
