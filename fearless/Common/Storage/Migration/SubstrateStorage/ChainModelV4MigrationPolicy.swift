import Foundation
import CoreData

class ChainModelV4MigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource chainModel: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: chainModel, in: mapping, manager: manager)

        guard let updatedChainModel = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [chainModel]
        ).first else {
            throw ConvenienceError(error: "Can't create destination instance")
        }

        guard let chainAssetsModels = chainModel.value(forKey: "assets") as? Set<NSManagedObject> else {
            throw ConvenienceError(error: "No assets value")
        }

        let assetModels: [NSManagedObject] = chainAssetsModels.compactMap {
            guard
                let assetModel = $0.value(forKey: "asset") as? NSManagedObject,
                let id = assetModel.value(forKey: "id") as? String,
                let symbol = assetModel.value(forKey: "symbol") as? String,
                let precision = assetModel.value(forKey: "precision") as? UInt16
            else {
                return nil
            }
            let icon = assetModel.value(forKey: "icon") as? URL
            let priceId = assetModel.value(forKey: "priceId") as? String
            let price = assetModel.value(forKey: "price") as? Decimal
            let fiatDayChange = assetModel.value(forKey: "fiatDayChange") as? String
            let currencyId = assetModel.value(forKey: "currencyId") as? String
            let existentialDeposit = assetModel.value(forKey: "existentialDeposit") as? String
            let color = assetModel.value(forKey: "color") as? String

            let isNative: Bool = ($0.value(forKey: "isNative") as? Bool) ?? false
            let isUtility: Bool = ($0.value(forKey: "isUtility") as? Bool) ?? false
            let purchaseProviders: [String]? = $0.value(forKey: "purchaseProviders") as? [String]
            let staking: String? = $0.value(forKey: "staking") as? String
            let type: String = ($0.value(forKey: "type") as? String) ?? "normal"

            let updatedAssetModel = NSEntityDescription.insertNewObject(
                forEntityName: "CDAsset",
                into: manager.destinationContext
            )

            updatedAssetModel.setValue(id, forKey: "id")
            updatedAssetModel.setValue(symbol, forKey: "symbol")
            updatedAssetModel.setValue(precision, forKey: "precision")
            updatedAssetModel.setValue(icon, forKey: "icon")
            updatedAssetModel.setValue(priceId, forKey: "priceId")
            updatedAssetModel.setValue(price, forKey: "price")
            updatedAssetModel.setValue(fiatDayChange, forKey: "fiatDayChange")
            updatedAssetModel.setValue(currencyId, forKey: "currencyId")
            updatedAssetModel.setValue(existentialDeposit, forKey: "existentialDeposit")
            updatedAssetModel.setValue(color, forKey: "color")
            updatedAssetModel.setValue(isNative, forKey: "isNative")
            updatedAssetModel.setValue(isUtility, forKey: "isUtility")
            updatedAssetModel.setValue(purchaseProviders, forKey: "purchaseProviders")
            updatedAssetModel.setValue(staking, forKey: "staking")
            updatedAssetModel.setValue(type, forKey: "type")

            return updatedAssetModel
        }
        let assetsSet = Set(assetModels) as NSSet

        let updatedAssetsSet = updatedChainModel.mutableSetValue(forKey: "assets")
        updatedAssetsSet.addObjects(from: assetsSet.allObjects)

        updatedChainModel.setValue(updatedAssetsSet, forKey: "assets")
        updatedChainModel.setValue(false, forKey: "disabled")

        manager.associate(
            sourceInstance: chainModel,
            withDestinationInstance: updatedChainModel,
            for: mapping
        )
    }
}
