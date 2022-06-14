import Foundation

struct PriceData: Codable, Equatable {
    let priceId: String
    let price: String
    let fiatDayChange: Decimal?
}
