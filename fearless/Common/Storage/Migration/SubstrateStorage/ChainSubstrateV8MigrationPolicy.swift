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

        guard let chainAssetsModels = sInstance.value(forKey: "assets") as? Set<NSManagedObject> else {
            throw ConvenienceError(error: "No assets value")
        }

        let assetModels: [NSManagedObject] = chainAssetsModels.compactMap {
            guard
                let id = $0.value(forKey: "id") as? String,
                let name = $0.value(forKey: "name") as? String,
                let symbol = $0.value(forKey: "symbol") as? String,
                let precision = $0.value(forKey: "precision") as? UInt16
            else {
                return nil
            }
            let icon = $0.value(forKey: "icon") as? URL
            let currencyId = $0.value(forKey: "currencyId") as? String
            let existentialDeposit = $0.value(forKey: "existentialDeposit") as? String
            let color = $0.value(forKey: "color") as? String
            let isUtility: Bool = ($0.value(forKey: "isUtility") as? Bool) ?? false
            let isNative: Bool = ($0.value(forKey: "isNative") as? Bool) ?? false
            let staking: String? = $0.value(forKey: "staking") as? String
            let purchaseProviders: [String]? = $0.value(forKey: "purchaseProviders") as? [String]
            let priceId: String? = $0.value(forKey: "priceId") as? String
            let priceProvider = $0.value(forKey: "priceProvider") as? NSManagedObject

            let updatedAssetModel = NSEntityDescription.insertNewObject(
                forEntityName: "CDAsset",
                into: manager.destinationContext
            )

            if let priceProviderId = priceProvider?.objectID {
                let priceProviderInDestinationContext = manager.destinationContext.object(with: priceProviderId)
                updatedAssetModel.setValue(priceProviderInDestinationContext, forKey: "priceProvider")
            }

            updatedAssetModel.setValue(name, forKey: "name")
            updatedAssetModel.setValue(id, forKey: "id")
            updatedAssetModel.setValue(symbol, forKey: "symbol")
            updatedAssetModel.setValue(precision, forKey: "precision")
            updatedAssetModel.setValue(icon, forKey: "icon")
            updatedAssetModel.setValue(currencyId, forKey: "currencyId")
            updatedAssetModel.setValue(existentialDeposit, forKey: "existentialDeposit")
            updatedAssetModel.setValue(color, forKey: "color")
            updatedAssetModel.setValue(isNative, forKey: "isNative")
            updatedAssetModel.setValue(isUtility, forKey: "isUtility")
            updatedAssetModel.setValue(purchaseProviders, forKey: "purchaseProviders")
            updatedAssetModel.setValue(staking, forKey: "staking")
            updatedAssetModel.setValue(priceId, forKey: "priceId")

            if let ethereumType = $0.value(forKey: "ethereumType") as? String {
                updatedAssetModel.setValue("ethereum-" + ethereumType, forKey: "type")
            } else if let type = $0.value(forKey: "type") as? String {
                updatedAssetModel.setValue("substrate-" + type, forKey: "type")
            }
            return updatedAssetModel
        }
        updatedChainModel.setValue(Set<NSManagedObject>(assetModels), forKey: "assets")

        manager.associate(
            sourceInstance: sInstance,
            withDestinationInstance: updatedChainModel,
            for: mapping
        )
    }
}
