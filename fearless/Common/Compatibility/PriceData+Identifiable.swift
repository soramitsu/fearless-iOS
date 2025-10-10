import Foundation
import SSFModels
import RobinHood

// CoreData mappers require RobinHood.Identifiable. Use priceId as stable identifier.
extension PriceData: RobinHood.Identifiable {
    public var identifier: String { priceId }
}
