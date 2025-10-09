import Foundation
import SSFModels

// SSFModels.PriceData doesn’t conform to Identifiable by default,
// but our CoreData mappers expect Identifiable models. Use priceId as the stable id.
extension PriceData: Identifiable {
    public var id: String { priceId }
}
