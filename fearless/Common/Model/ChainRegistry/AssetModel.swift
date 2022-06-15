import Foundation
import RobinHood

struct AssetModel: Equatable, Codable, Hashable {
    // swiftlint:disable:next type_name
    typealias Id = String
    typealias PriceId = String

    let id: String
    let symbol: String
    let chainId: String
    let precision: UInt16
    let icon: URL?
    let priceId: PriceId?
    let price: Decimal?
    let transfersEnabled: Bool?
    let type: ChainAssetType
    let currencyId: String?
    let displayName: String?
    let existentialDeposit: String?

    var name: String {
        displayName?.uppercased() ?? symbol.uppercased()
    }

    init(
        id: String,
        symbol: String,
        chainId: String,
        precision: UInt16,
        icon: URL?,
        priceId: AssetModel.PriceId?,
        price: Decimal?,
        transfersEnabled: Bool?,
        type: ChainAssetType,
        currencyId: String?,
        displayName: String?,
        existentialDeposit: String?
    ) {
        self.id = id
        self.symbol = symbol
        self.chainId = chainId
        self.precision = precision
        self.icon = icon
        self.priceId = priceId
        self.price = price
        self.transfersEnabled = transfersEnabled
        self.type = type
        self.currencyId = currencyId
        self.displayName = displayName
        self.existentialDeposit = existentialDeposit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        symbol = try container.decode(String.self, forKey: .symbol)
        chainId = try container.decode(String.self, forKey: .chainId)
        precision = try container.decode(UInt16.self, forKey: .precision)
        icon = try? container.decode(URL?.self, forKey: .icon)
        priceId = try? container.decode(String?.self, forKey: .priceId)
        transfersEnabled = try? container.decode(Bool?.self, forKey: .transfersEnabled)
        currencyId = try? container.decode(String?.self, forKey: .currencyId)
        displayName = try? container.decode(String?.self, forKey: .displayName)
        existentialDeposit = try? container.decode(String?.self, forKey: .existentialDeposit)

        price = nil
        type = .normal
    }

    func replacingPrice(_ newPrice: Decimal?) -> AssetModel {
        AssetModel(
            id: id,
            symbol: symbol,
            chainId: chainId,
            precision: precision,
            icon: icon,
            priceId: priceId,
            price: newPrice,
            transfersEnabled: transfersEnabled,
            type: type,
            currencyId: currencyId,
            displayName: displayName,
            existentialDeposit: existentialDeposit
        )
    }

    static func == (lhs: AssetModel, rhs: AssetModel) -> Bool {
        lhs.id == rhs.id &&
            lhs.chainId == rhs.chainId &&
            lhs.precision == rhs.precision &&
            lhs.icon == rhs.icon &&
            lhs.priceId == rhs.priceId &&
            lhs.symbol == rhs.symbol &&
            lhs.type == rhs.type &&
            lhs.transfersEnabled == rhs.transfersEnabled &&
            lhs.currencyId == rhs.currencyId &&
            lhs.displayName == rhs.displayName
    }
}

extension AssetModel: Identifiable {
    var identifier: String { id }
}
