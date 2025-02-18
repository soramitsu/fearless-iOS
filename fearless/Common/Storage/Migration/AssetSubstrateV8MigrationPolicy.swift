import Foundation
import SSFModels
import CoreData

class AssetSubstrateV8MigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        guard let updatedAssetModel = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else {
            throw ConvenienceError(error: "Can't create destination instance")
        }

        if let ethereumType = sInstance.value(forKey: "ethereumType") as? String {
            updatedAssetModel.setValue("ethereum-" + ethereumType, forKey: "type")
        } else if let type = sInstance.value(forKey: "type") as? String {
            updatedAssetModel.setValue("substrate-" + type, forKey: "type")
        }

        manager.associate(
            sourceInstance: sInstance,
            withDestinationInstance: updatedAssetModel,
            for: mapping
        )
    }
}
