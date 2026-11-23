import Foundation

public struct AssetBalance: Hashable, Sendable {
    public var assetID: AssetID
    /// Everything the account owns of the asset (free + reserved).
    public var total: TokenAmount
    /// What can be sent right now.
    public var transferable: TokenAmount
    /// Reserved, frozen, staked or otherwise locked.
    public var locked: TokenAmount
    public var updatedAt: Date

    public init(assetID: AssetID, total: TokenAmount, transferable: TokenAmount, locked: TokenAmount, updatedAt: Date = Date()) {
        self.assetID = assetID
        self.total = total
        self.transferable = transferable
        self.locked = locked
        self.updatedAt = updatedAt
    }
}

public struct FiatCurrency: Hashable, Codable, Sendable, Identifiable {
    /// Lowercase ISO code as used by price feeds (`"usd"`).
    public var code: String
    public var symbol: String
    public var name: String

    public var id: String { code }

    public init(code: String, symbol: String, name: String) {
        self.code = code
        self.symbol = symbol
        self.name = name
    }

    public static let usd = FiatCurrency(code: "usd", symbol: "$", name: "US Dollar")
    public static let eur = FiatCurrency(code: "eur", symbol: "€", name: "Euro")
    public static let jpy = FiatCurrency(code: "jpy", symbol: "¥", name: "Japanese Yen")
    public static let gbp = FiatCurrency(code: "gbp", symbol: "£", name: "British Pound")
    public static let chf = FiatCurrency(code: "chf", symbol: "CHF", name: "Swiss Franc")
    public static let krw = FiatCurrency(code: "krw", symbol: "₩", name: "South Korean Won")
    public static let cny = FiatCurrency(code: "cny", symbol: "¥", name: "Chinese Yuan")
    public static let inr = FiatCurrency(code: "inr", symbol: "₹", name: "Indian Rupee")
    public static let rub = FiatCurrency(code: "rub", symbol: "₽", name: "Russian Ruble")
    public static let brl = FiatCurrency(code: "brl", symbol: "R$", name: "Brazilian Real")

    public static let all: [FiatCurrency] = [.usd, .eur, .jpy, .gbp, .chf, .krw, .cny, .inr, .rub, .brl]

    public static func named(_ code: String) -> FiatCurrency? {
        all.first { $0.code == code.lowercased() }
    }
}

public struct AssetPrice: Hashable, Sendable {
    public var priceID: String
    public var currency: FiatCurrency
    public var value: Decimal
    /// 24 h change in percent (e.g. `-2.5`).
    public var change24h: Decimal?
    public var updatedAt: Date

    public init(priceID: String, currency: FiatCurrency, value: Decimal, change24h: Decimal?, updatedAt: Date = Date()) {
        self.priceID = priceID
        self.currency = currency
        self.value = value
        self.change24h = change24h
        self.updatedAt = updatedAt
    }
}

public enum ActivityDirection: String, Codable, Sendable, Hashable {
    case outgoing
    case incoming
    case selfTransfer
    case other
}

public enum ActivityStatus: String, Codable, Sendable, Hashable {
    case pending
    case success
    case failed
}

public struct ActivityItem: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var walletID: WalletID
    public var assetID: AssetID
    public var direction: ActivityDirection
    /// Other party's address, formatted for the chain.
    public var counterparty: String?
    public var amount: TokenAmount
    public var fee: TokenAmount?
    public var timestamp: Date
    public var status: ActivityStatus
    public var hash: String?
    public var explorerURL: URL?
    /// Short label for `.other` items (e.g. "Staking reward").
    public var title: String?

    public init(
        id: String,
        walletID: WalletID,
        assetID: AssetID,
        direction: ActivityDirection,
        counterparty: String?,
        amount: TokenAmount,
        fee: TokenAmount?,
        timestamp: Date,
        status: ActivityStatus,
        hash: String?,
        explorerURL: URL?,
        title: String? = nil
    ) {
        self.id = id
        self.walletID = walletID
        self.assetID = assetID
        self.direction = direction
        self.counterparty = counterparty
        self.amount = amount
        self.fee = fee
        self.timestamp = timestamp
        self.status = status
        self.hash = hash
        self.explorerURL = explorerURL
        self.title = title
    }
}

public struct ActivityPage: Hashable, Sendable {
    public var items: [ActivityItem]
    /// Chains whose history could not be loaded, with a short user-facing reason.
    public var unavailable: [ChainID: String]

    public init(items: [ActivityItem], unavailable: [ChainID: String] = [:]) {
        self.items = items
        self.unavailable = unavailable
    }
}
