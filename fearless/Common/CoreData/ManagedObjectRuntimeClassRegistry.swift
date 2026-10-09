import CoreData
import Foundation

#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
    private typealias RuntimeCDPolkaswapDex =
        SSFAssetManagmentStorage.CDPolkaswapDex
    private typealias RuntimeCDScamInfo =
        SSFAssetManagmentStorage.CDScamInfo
#else
    private typealias RuntimeCDPolkaswapDex =
        SSFAssetManagmentStorageStub.CDPolkaswapDex
    private typealias RuntimeCDScamInfo =
        SSFAssetManagmentStorageStub.CDScamInfo
#endif

/// Strong, production-used references to every managed-object class named by
/// the current bundled stores. This prevents normal Release dead stripping
/// from making a model class disappear only outside ENABLE_TESTABILITY builds.
enum ManagedObjectRuntimeClassRegistry {
    static let substrateV8Classes: [NSManagedObject.Type] = [
        CDAsset.self,
        CDChain.self,
        CDChainNode.self,
        CDChainStorageItem.self,
        CDChainXcmConfig.self,
        CDContact.self,
        CDContactItem.self,
        CDExternalApi.self,
        CDPhishingItem.self,
        RuntimeCDPolkaswapDex.self,
        CDPolkaswapRemoteSettings.self,
        CDPriceData.self,
        CDPriceProvider.self,
        CDRuntimeMetadataItem.self,
        RuntimeCDScamInfo.self,
        CDStashItem.self,
        CDTransactionHistoryItem.self,
        CDXcmAvailableAsset.self,
        CDXcmAvailableDestination.self
    ]

    static let userV11Classes: [NSManagedObject.Type] = [
        CDAccountInfo.self,
        CDAssetVisibility.self,
        CDChainAccount.self,
        CDChainSettings.self,
        CDCurrency.self,
        CDCustomChainNode.self,
        CDMetaAccount.self
    ]

    static let classesByRuntimeName: [String: NSManagedObject.Type] = {
        Dictionary(
            uniqueKeysWithValues: (substrateV8Classes + userV11Classes).map {
                (NSStringFromClass($0), $0)
            }
        )
    }()

    static func resolve(className: String) -> NSManagedObject.Type? {
        if let registeredClass = classesByRuntimeName[className] {
            return registeredClass
        }

        if let registeredClass = classesByRuntimeName.first(where: {
            $0.key.split(separator: ".").last.map(String.init) == className
        })?.value {
            return registeredClass
        }

        return NSClassFromString(className) as? NSManagedObject.Type
    }
}
