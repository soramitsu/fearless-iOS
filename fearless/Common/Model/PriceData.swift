import Foundation

struct PriceData: Codable, Equatable {
    let price: String
    let fiatDayChange: Decimal?
}
