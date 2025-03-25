import Foundation
import SSFModels
import CoreData

class ChainSubstrateV8MigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        guard let updatedChainModel = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else {
            throw ConvenienceError(error: "Can't create destination instance")
        }

        let options = sInstance.value(forKey: "options") as? [String]
        if options?.contains("ethereum") == true {
            updatedChainModel.setValue("ethereum", forKey: "ecosystem")
        } else if options?.contains("ethereumBased") == true {
            updatedChainModel.setValue("ethereumBased", forKey: "ecosystem")
        } else {
            updatedChainModel.setValue("substrate", forKey: "ecosystem")
        }

        manager.associate(
            sourceInstance: sInstance,
            withDestinationInstance: updatedChainModel,
            for: mapping
        )
    }
}
