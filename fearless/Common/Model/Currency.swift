import Foundation

struct Currency: Codable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let icon: String
    var isSelected: Bool?

    static func defaultCurrency() -> Currency {
        Currency(
            id: "usd",
            symbol: "$",
            name: "US Dollar",
            icon: "https://raw.githubusercontent.com/soramitsu/fearless-utils/android/2.0.2/icons/fiat/usd.svg",
            isSelected: true
        )
    }
}
