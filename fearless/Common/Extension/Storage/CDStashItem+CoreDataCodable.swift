import Foundation
import CoreData
import RobinHood

extension CDStashItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using context: NSManagedObjectContext) throws {
        let stashItem = try StashItem(from: decoder)

        stash = stashItem.stash
        controller = stashItem.controller
    }

    public func encode(to encoder: Encoder) throws {
        guard let stash = stash, let controller = controller else {
            return
        }

        try StashItem(stash: stash, controller: controller).encode(to: encoder)
    }
}
