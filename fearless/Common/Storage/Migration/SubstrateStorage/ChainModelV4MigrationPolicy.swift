import Foundation
import CoreData

class ChainModelV4MigrationPolicy: NSEntityMigrationPolicy {
    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        let entityName = "CDChain"
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        let context = manager.sourceContext
        let results = try context.fetch(request)
        results.forEach(context.delete)
        try super.begin(mapping, with: manager)
    }
}
