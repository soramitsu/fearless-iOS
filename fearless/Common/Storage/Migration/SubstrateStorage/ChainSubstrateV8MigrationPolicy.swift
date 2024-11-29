import Foundation
import CoreData

class ChainSubstrateV8MigrationPolicy: NSEntityMigrationPolicy {
    override func createRelationships(
        forDestination chainModel: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createRelationships(forDestination: chainModel, in: mapping, manager: manager)

        guard let options = chainModel.value(forKey: "options") as? [String] else {
            chainModel.setValue("substrate", forKey: "ecosystem")
            return
        }

        if options.contains("ethereum") {
            chainModel.setValue("ethereum", forKey: "ecosystem")
        } else if options.contains("ethereumBased") {
            chainModel.setValue("ethereumBased", forKey: "ecosystem")
        } else {
            chainModel.setValue("substrate", forKey: "ecosystem")
        }
    }
}
