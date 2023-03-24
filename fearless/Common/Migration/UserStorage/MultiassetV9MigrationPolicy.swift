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
        ).first as? CDMetaAccount else {
            return
        }

        let assetsVisibility = assetIdsEnabled.compactMap { AssetVisibility(assetId: $0, hidden: false) }
        let assetsVisibilitySet = Set(assetsVisibility) as NSSet

        updatedWallet.assetsVisibility = assetsVisibilitySet
    }
}
