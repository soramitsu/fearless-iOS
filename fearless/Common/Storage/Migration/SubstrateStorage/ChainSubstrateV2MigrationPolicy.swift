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

        guard chainModel.value(forKey: "selectedNode") == nil,
              let nodes = chainModel.value(forKey: "nodes") as? Set<NSManagedObject>,
              let node = nodes.min(by: isOrderedBefore) else {
            return
        }

        chainModel.setValue(node, forKey: "selectedNode")
    }

    private func isOrderedBefore(
        _ lhs: NSManagedObject,
        _ rhs: NSManagedObject
    ) -> Bool {
        let lhsURL = (lhs.value(forKey: "url") as? URL)?.absoluteString ?? ""
        let rhsURL = (rhs.value(forKey: "url") as? URL)?.absoluteString ?? ""

        if lhsURL != rhsURL {
            return lhsURL < rhsURL
        }

        let lhsName = lhs.value(forKey: "name") as? String ?? ""
        let rhsName = rhs.value(forKey: "name") as? String ?? ""

        if lhsName != rhsName {
            return lhsName < rhsName
        }

        return lhs.objectID.uriRepresentation().absoluteString <
            rhs.objectID.uriRepresentation().absoluteString
    }
}
