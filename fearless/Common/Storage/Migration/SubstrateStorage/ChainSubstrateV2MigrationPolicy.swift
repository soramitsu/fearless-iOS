import Foundation
import CoreData
import IrohaCrypto

class ChainSubstrateV2MigrationPolicy: NSEntityMigrationPolicy {
    override func createRelationships(
        forDestination chainModel: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createRelationships(forDestination: chainModel, in: mapping, manager: manager)

        guard let nodes = chainModel.value(forKey: "nodes") as? Set<NSManagedObject>,
              let node = nodes.first else {
            return
        }

        chainModel.setValue(node, forKey: "selectedNode")
    }
}
