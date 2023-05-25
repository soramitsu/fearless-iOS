import Foundation
import CoreData
import IrohaCrypto

class MultiassetV9MigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource wallet: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: wallet, in: mapping, manager: manager)

        guard let assetIdsEnabled = wallet.value(forKey: "assetIdsEnabled") as? [String] else {
            return
        }

        guard let updatedWallet = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [wallet]
        ).first else {
            return
        }

        let assetsVisibility: [NSManagedObject] = assetIdsEnabled.compactMap {
            let entityDescription = NSEntityDescription.insertNewObject(forEntityName: "CDAssetVisibility", into: manager.destinationContext)
            entityDescription.setValue($0, forKey: "assetId")
            entityDescription.setValue(true, forKey: "hidden")
            entityDescription.setValue(updatedWallet, forKey: "wallet")
            return entityDescription
        }
        let assetsVisibilitySet = Set(assetsVisibility) as NSSet

        let updatedAssetsVisibilitySet = updatedWallet.mutableSetValue(forKey: "assetsVisibility")
        updatedAssetsVisibilitySet.addObjects(from: assetsVisibilitySet.allObjects)

        updatedWallet.setValue(updatedAssetsVisibilitySet, forKey: "assetsVisibility")

        manager.associate(sourceInstance: wallet, withDestinationInstance: updatedWallet, for: mapping)
    }
}
