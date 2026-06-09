import Foundation
import CoreData
import IrohaCrypto

class MultiassetV2MigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource _: NSManagedObject,
        in _: NSEntityMapping,
        manager _: NSMigrationManager
    ) throws {
        // No-op policy: this migration stage only removes obsolete entities.
    }
}
