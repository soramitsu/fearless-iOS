import Foundation
import SSFModels

extension PriceData: @retroactive Identifiable {
    public typealias ID = String
    public var id: String { "\(currencyId):\(priceId)" }
}
