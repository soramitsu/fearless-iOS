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
    let fiatDayChange: Decimal?
    let transfersEnabled: Bool?
    let type: ChainAssetType
    let currencyId: String?
    let displayName: String?
    let existentialDeposit: String?
    let accountInfo: AccountInfo?

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
        fiatDayChange: Decimal?,
        transfersEnabled: Bool?,
        type: ChainAssetType,
        currencyId: String?,
        displayName: String?,
        existentialDeposit: String?,
        accountInfo: AccountInfo?
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
        self.type = type
        self.currencyId = currencyId
        self.displayName = displayName
        self.existentialDeposit = existentialDeposit
        self.accountInfo = accountInfo
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
        fiatDayChange = nil
        type = .normal
        accountInfo = nil
    }

    func replacingPrice(_ newPrice: Decimal?, fiatDayChange: Decimal?) -> AssetModel {
        AssetModel(
            id: id,
            symbol: symbol,
            chainId: chainId,
            precision: precision,
            icon: icon,
            priceId: priceId,
            price: newPrice,
            fiatDayChange: fiatDayChange,
            transfersEnabled: transfersEnabled,
            type: type,
            currencyId: currencyId,
            displayName: displayName,
            existentialDeposit: existentialDeposit,
            accountInfo: accountInfo
        )
    }

    func replacingAccountInfo(_ accountInfo: AccountInfo?) -> AssetModel {
        AssetModel(
            id: id,
            symbol: symbol,
            chainId: chainId,
            precision: precision,
            icon: icon,
            priceId: priceId,
            price: price,
            fiatDayChange: fiatDayChange,
            transfersEnabled: transfersEnabled,
            type: type,
            currencyId: currencyId,
            displayName: displayName,
            existentialDeposit: existentialDeposit,
            accountInfo: accountInfo
        )
    }

    static func == (lhs: AssetModel, rhs: AssetModel) -> Bool {
        lhs.id == rhs.id &&
            lhs.chainId == rhs.chainId
    }
}

extension AssetModel: Identifiable {
    var identifier: String { id }
}
