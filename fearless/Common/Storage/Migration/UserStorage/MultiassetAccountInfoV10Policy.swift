import Foundation
import CoreData

class MultiassetAccountInfoV10Policy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource _: NSManagedObject,
        in _: NSEntityMapping,
        manager _: NSMigrationManager
    ) throws {}
}
