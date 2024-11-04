import CoreData

class CDChainAccountMigrationPolicyV12: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        if let destination = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first {
            destination.setValue(nil, forKey: "ecosystem")
        }
    }
}
