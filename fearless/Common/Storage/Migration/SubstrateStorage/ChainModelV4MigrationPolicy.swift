import Foundation
import CoreData

class ChainModelV4MigrationPolicy: NSEntityMigrationPolicy {
    private enum Constants {
        static let assetEntityName = "CDAsset"
        static let assetsRelationshipName = "assets"
        static let disabledAttributeName = "disabled"
        static let legacyAssetRelationshipName = "asset"
        static let wrapperMetadataKeys = [
            "isNative",
            "isUtility",
            "purchaseProviders",
            "staking",
            "type"
        ]
    }

    override func createDestinationInstances(
        forSource chainModel: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: chainModel, in: mapping, manager: manager)

        guard let destinationChain = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [chainModel]
        ).first else {
            throw ConvenienceError(error: "Can't create destination instance")
        }

        destinationChain.setValue(
            false,
            forKey: Constants.disabledAttributeName
        )
    }

    override func createRelationships(
        forDestination destinationChain: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createRelationships(
            forDestination: destinationChain,
            in: mapping,
            manager: manager
        )

        guard let sourceChain = manager.sourceInstances(
            forEntityMappingName: mapping.name,
            destinationInstances: [destinationChain]
        ).first else {
            return
        }

        let legacyWrappers =
            sourceChain.value(forKey: Constants.assetsRelationshipName) as? Set<NSManagedObject>
                ?? []
        guard !legacyWrappers.isEmpty else {
            return
        }

        guard
            let assetMappingName = manager.mappingModel.entityMappings.first(where: {
                $0.sourceEntityName == Constants.assetEntityName &&
                    $0.destinationEntityName == Constants.assetEntityName
            })?.name
        else {
            throw ConvenienceError(error: "Can't find the CDAsset entity mapping")
        }

        let destinationAssets = destinationChain.mutableSetValue(
            forKey: Constants.assetsRelationshipName
        )

        for wrapper in legacyWrappers {
            guard let sourceAsset = wrapper.value(
                forKey: Constants.legacyAssetRelationshipName
            ) as? NSManagedObject else {
                continue
            }

            guard let destinationAsset = manager.destinationInstances(
                forEntityMappingName: assetMappingName,
                sourceInstances: [sourceAsset]
            ).first else {
                throw ConvenienceError(
                    error: "Can't find migrated CDAsset destination instance"
                )
            }

            copyWrapperMetadata(
                from: wrapper,
                to: destinationAsset
            )
            destinationAssets.add(destinationAsset)
        }
    }

    private func copyWrapperMetadata(
        from wrapper: NSManagedObject,
        to destinationAsset: NSManagedObject
    ) {
        for key in Constants.wrapperMetadataKeys {
            let value: Any?
            if key == "purchaseProviders" {
                value = try? SafeTransformableValueReader.read(
                    from: wrapper,
                    key: key,
                    as: NSArray.self
                )
            } else {
                value = wrapper.value(forKey: key)
            }

            guard let value else {
                continue
            }

            destinationAsset.setValue(value, forKey: key)
        }

        if destinationAsset.value(forKey: "type") == nil {
            destinationAsset.setValue("normal", forKey: "type")
        }
    }
}
