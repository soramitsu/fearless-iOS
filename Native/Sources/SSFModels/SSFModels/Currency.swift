import Foundation

public struct Currency: Codable, Equatable, Hashable {
    public let id: String
    public let symbol: String
    public let name: String
    public let icon: String
    public var isSelected: Bool?

    public static func defaultCurrency() -> Currency {
        Currency(
            id: "usd",
            symbol: "$",
            name: "US Dollar",
            icon: "https://raw.githubusercontent.com/soramitsu/fearless-iOS/master/remote-config/legacy/android/2.0.2/icons/fiat/usd.svg",
            isSelected: true
        )
    }

    public static func euro() -> Currency {
        Currency(
            id: "eur",
            symbol: "€",
            name: "Euro",
            icon: "https://raw.githubusercontent.com/soramitsu/fearless-iOS/master/remote-config/legacy/android/2.0.2/icons/fiat/eur.svg",
            isSelected: false
        )
    }

    public init(id: String, symbol: String, name: String, icon: String, isSelected: Bool? = nil) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.icon = icon
        self.isSelected = isSelected
    }
}
