import Foundation
import RobinHood
import SSFModels

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
    let fiatDayChange: Decimal?
    let transfersEnabled: Bool
    let currencyId: String?
    let displayName: String?
    let existentialDeposit: String?
    let color: String?

    var name: String {
        symbol.uppercased()
    }

    init(
        id: String,
        symbol: String,
        chainId: String,
        precision: UInt16,
        icon: URL?,
        priceId: AssetModel.PriceId?,
        price: Decimal?,
        fiatDayChange: Decimal?,
        transfersEnabled: Bool,
        currencyId: String?,
        displayName: String?,
        existentialDeposit: String?,
        color: String?
    ) {
        self.id = id
        self.symbol = symbol
        self.chainId = chainId
        self.precision = precision
        self.icon = icon
        self.priceId = priceId
        self.price = price
        self.fiatDayChange = fiatDayChange
        self.transfersEnabled = transfersEnabled
        self.currencyId = currencyId
        self.displayName = displayName
        self.existentialDeposit = existentialDeposit
        self.color = color
    }

    enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case chainId
        case precision
        case icon
        case priceId
        case transfersEnabled
        case currencyId
        case displayName = "name"
        case existentialDeposit
        case color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        symbol = try container.decode(String.self, forKey: .symbol)
        chainId = try container.decode(String.self, forKey: .chainId)
        precision = try container.decode(UInt16.self, forKey: .precision)
        icon = try? container.decode(URL?.self, forKey: .icon)
        priceId = try? container.decode(String?.self, forKey: .priceId)
        transfersEnabled = (try? container.decode(Bool?.self, forKey: .transfersEnabled)) ?? true
        currencyId = try? container.decode(String?.self, forKey: .currencyId)
        displayName = try? container.decode(String?.self, forKey: .displayName)
        existentialDeposit = try? container.decode(String?.self, forKey: .existentialDeposit)
        color = try? container.decode(String.self, forKey: .color)

        price = nil
        fiatDayChange = nil
    }

    func replacingPrice(_ priceData: PriceData) -> AssetModel {
        AssetModel(
            id: id,
            symbol: symbol,
            chainId: chainId,
            precision: precision,
            icon: icon,
            priceId: priceId,
            price: Decimal(string: priceData.price),
            fiatDayChange: priceData.fiatDayChange,
            transfersEnabled: transfersEnabled,
            currencyId: currencyId,
            displayName: displayName,
            existentialDeposit: existentialDeposit,
            color: color
        )
    }

    static func == (lhs: AssetModel, rhs: AssetModel) -> Bool {
        lhs.id == rhs.id &&
            lhs.chainId == rhs.chainId &&
            lhs.precision == rhs.precision &&
            lhs.icon == rhs.icon &&
            lhs.priceId == rhs.priceId &&
            lhs.symbol == rhs.symbol &&
            lhs.transfersEnabled == rhs.transfersEnabled &&
            lhs.currencyId == rhs.currencyId &&
            lhs.displayName == rhs.displayName &&
            lhs.existentialDeposit == rhs.existentialDeposit &&
            lhs.color == rhs.color
    }
}

extension AssetModel: Identifiable {
    var identifier: String { id }
}

// extension AssetModel: AssetModelProtocol {}
