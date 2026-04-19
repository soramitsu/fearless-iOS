import Foundation
import SSFModels

extension PriceData: Identifiable {
    public typealias ID = String
    public var id: String { "\(currencyId):\(priceId)" }
}
