import Foundation

struct PriceData: Codable, Equatable {
    let price: String
    let usdDayChange: Decimal?
}
