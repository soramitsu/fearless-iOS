import Foundation
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#else
    import CoreData
    import RobinHood

    // Lightweight stand-in for the private SSFAssetManagmentStorage pod.
    // These classes only need to exist so the rest of the app can compile when
    // the private pod is not available (e.g. in OSS builds or PRs).
    public enum SSFAssetManagmentStorageStub {
        open class CoreDataStubObject: NSManagedObject, CoreDataCodable {
            open func populate(from _: Decoder, using _: NSManagedObjectContext) throws {}

            open func encode(to _: Encoder) throws {}
        }

        public class CDChain: CoreDataStubObject {
            @NSManaged public var rank: String?
            @NSManaged public var disabled: Bool
            @NSManaged public var chainId: String?
            @NSManaged public var parentId: String?
            @NSManaged public var name: String?
            @NSManaged public var types: String?
            @NSManaged public var typesOverrideCommon: NSNumber?
            @NSManaged public var addressPrefix: Int16
            @NSManaged public var icon: URL?
            @NSManaged public var isEthereumBased: Bool
            @NSManaged public var isTestnet: Bool
            @NSManaged public var hasCrowdloans: Bool
            @NSManaged public var isTipRequired: Bool
            @NSManaged public var minimalAppVersion: String?
            @NSManaged public var options: NSArray?
            @NSManaged public var assets: NSSet?
            @NSManaged public var nodes: NSSet?
            @NSManaged public var customNodes: NSSet?
            @NSManaged public var selectedNode: CDChainNode?
            @NSManaged public var stakingApiType: String?
            @NSManaged public var stakingApiUrl: URL?
            @NSManaged public var historyApiType: String?
            @NSManaged public var historyApiUrl: URL?
            @NSManaged public var crowdloansApiType: String?
            @NSManaged public var crowdloansApiUrl: URL?
            @NSManaged public var xcmConfig: CDChainXcmConfig?
            @NSManaged public var explorers: NSSet?
        }

        public class CDAsset: CoreDataStubObject {
            @NSManaged public var id: String?
            @NSManaged public var icon: URL?
            @NSManaged public var precision: Int16
            @NSManaged public var priceId: String?
            @NSManaged public var symbol: String?
            @NSManaged public var existentialDeposit: String?
            @NSManaged public var color: String?
            @NSManaged public var name: String?
            @NSManaged public var currencyId: String?
            @NSManaged public var type: String?
            @NSManaged public var isUtility: Bool
            @NSManaged public var isNative: Bool
            @NSManaged public var staking: String?
            @NSManaged public var ethereumType: String?
            @NSManaged public var priceProvider: CDPriceProvider?
            @NSManaged public var purchaseProviders: [String]?
        }

        public class CDChainAsset: CoreDataStubObject {}
        public class CDChainNode: CoreDataStubObject {
            @NSManaged public var url: URL?
            @NSManaged public var name: String?
            @NSManaged public var apiKeyName: String?
            @NSManaged public var apiQueryName: String?
        }

        public class CDChainStorageItem: CoreDataStubObject {
            @NSManaged public var identifier: String?
        }

        public class CDRuntimeMetadataItem: CoreDataStubObject {}
        public class CDAccountInfo: CoreDataStubObject {
            @NSManaged public var identifier: String?
        }

        public class CDStashItem: CoreDataStubObject {
            @NSManaged public var stash: String?
            @NSManaged public var controller: String?
        }

        public class CDSingleValue: CoreDataStubObject {}
        public class CDChainSettings: CoreDataStubObject {
            @NSManaged public var chainId: String?
            @NSManaged public var autobalanced: Bool
            @NSManaged public var issueMuted: Bool
        }

        public class CDAssetVisibility: CoreDataStubObject {
            @NSManaged public var assetId: String?
            @NSManaged public var hidden: Bool
            @NSManaged public var wallet: CDMetaAccount?
        }

        public class CDMetaAccount: CoreDataStubObject {
            @NSManaged public var metaId: String?
            @NSManaged public var name: String?
            @NSManaged public var isSelected: Bool
            @NSManaged public var order: Int32
            @NSManaged public var substrateAccountId: String?
            @NSManaged public var substratePublicKey: Data?
            @NSManaged public var substrateCryptoType: Int16
            @NSManaged public var ethereumAddress: String?
            @NSManaged public var ethereumPublicKey: Data?
            @NSManaged public var chainAccounts: NSSet?
            @NSManaged public var assetKeysOrder: NSArray?
            @NSManaged public var canExportEthereumMnemonic: Bool
            @NSManaged public var unusedChainIds: NSArray?
            @NSManaged public var selectedCurrency: CDCurrency?
            @NSManaged public var networkManagmentFilter: String?
            @NSManaged public var hasBackup: Bool
            @NSManaged public var favouriteChainIds: NSArray?

            public func addToChainAccounts(_ value: CDChainAccount) {
                let mutable = mutableSetValue(forKey: "chainAccounts")
                mutable.add(value)
            }
        }

        public class CDChainAccount: CoreDataStubObject {
            @NSManaged public var accountId: String?
            @NSManaged public var publicKey: Data?
            @NSManaged public var cryptoType: Int16
            @NSManaged public var ethereumBased: Bool
            @NSManaged public var chainId: String?
            @NSManaged public var metaAccount: CDMetaAccount?
        }

        public class CDCustomChainNode: CoreDataStubObject {
            @NSManaged public var chainId: String?
            @NSManaged public var url: URL?
            @NSManaged public var name: String?
        }

        public class CDAccountItem: CoreDataStubObject {}
        public class CDPolkaswapRemoteSettings: CoreDataStubObject {
            @NSManaged public var version: String?
            @NSManaged public var availableSources: [String]?
            @NSManaged public var forceSmartIds: [String]?
            @NSManaged public var availableDexIds: NSSet?
            @NSManaged public var xstusdId: String?
        }

        public class CDPolkaswapDex: CoreDataStubObject {
            @NSManaged public var name: String?
            @NSManaged public var code: Int32
            @NSManaged public var assetId: String?
        }

        public class CDPhishingItem: CoreDataStubObject {}
        public class CDScamInfo: CoreDataStubObject {}
        public class CDPriceData: CoreDataStubObject {}
        public class CDPriceProvider: CoreDataStubObject {
            @NSManaged public var type: String?
            @NSManaged public var id: String?
            @NSManaged public var precision: String?
        }

        public class CDContactItem: CoreDataStubObject {}
        public class CDContact: CoreDataStubObject {}
        public class CDCurrency: CoreDataStubObject {
            @NSManaged public var id: String?
            @NSManaged public var symbol: String?
            @NSManaged public var name: String?
            @NSManaged public var icon: String?
            @NSManaged public var isSelected: Bool
        }

        public class CDExternalApi: CoreDataStubObject {
            @NSManaged public var type: String?
            @NSManaged public var types: NSArray?
            @NSManaged public var url: URL?
        }

        public class CDXcmAvailableDestination: CoreDataStubObject {
            @NSManaged public var chainId: String?
            @NSManaged public var bridgeParachainId: String?
            @NSManaged public var assets: NSSet?
        }

        public class CDXcmAvailableAsset: CoreDataStubObject {
            @NSManaged public var id: String?
            @NSManaged public var symbol: String?
        }

        public class CDChainXcmConfig: CoreDataStubObject {
            @NSManaged public var xcmVersion: String?
            @NSManaged public var destWeightIsPrimitive: Bool
            @NSManaged public var availableAssets: NSSet?
            @NSManaged public var availableDestinations: NSSet?
        }
    }

    public typealias SSFAssetManagmentStorage = SSFAssetManagmentStorageStub
#endif
#if canImport(SSFAccountManagmentStorage)
    import SSFAccountManagmentStorage
#endif
#if canImport(SSFSingleValueCache)
    import SSFSingleValueCache
#endif

// Alias Core Data entity classes provided by the storage modules so existing
// code can refer to unqualified names without generating duplicates in the app.

public typealias CDChain = SSFAssetManagmentStorage.CDChain
public typealias CDAsset = SSFAssetManagmentStorage.CDAsset
public typealias CDChainAsset = SSFAssetManagmentStorage.CDChainAsset
public typealias CDChainNode = SSFAssetManagmentStorage.CDChainNode
public typealias CDChainStorageItem = SSFAssetManagmentStorage.CDChainStorageItem
public typealias CDRuntimeMetadataItem = SSFAssetManagmentStorage.CDRuntimeMetadataItem
public typealias CDAccountInfo = SSFAssetManagmentStorage.CDAccountInfo
public typealias CDStashItem = SSFAssetManagmentStorage.CDStashItem
#if canImport(SSFSingleValueCache)
    public typealias CDSingleValue = SSFSingleValueCache.CDSingleValue
#else
    public typealias CDSingleValue = SSFAssetManagmentStorage.CDSingleValue
#endif
public typealias CDChainSettings = SSFAssetManagmentStorage.CDChainSettings
public typealias CDAssetVisibility = SSFAssetManagmentStorage.CDAssetVisibility
public typealias CDMetaAccount = SSFAssetManagmentStorage.CDMetaAccount
public typealias CDChainAccount = SSFAssetManagmentStorage.CDChainAccount
public typealias CDCustomChainNode = SSFAssetManagmentStorage.CDCustomChainNode
public typealias CDPolkaswapRemoteSettings = SSFAssetManagmentStorage.CDPolkaswapRemoteSettings
public typealias CDPhishingItem = SSFAssetManagmentStorage.CDPhishingItem
public typealias CDPriceData = SSFAssetManagmentStorage.CDPriceData
public typealias CDPriceProvider = SSFAssetManagmentStorage.CDPriceProvider
public typealias CDCurrency = SSFAssetManagmentStorage.CDCurrency
public typealias CDContactItem = SSFAssetManagmentStorage.CDContactItem
public typealias CDContact = SSFAssetManagmentStorage.CDContact
public typealias CDAccountItem = SSFAssetManagmentStorage.CDAccountItem
public typealias CDExternalApi = SSFAssetManagmentStorage.CDExternalApi
public typealias CDXcmAvailableDestination = SSFAssetManagmentStorage.CDXcmAvailableDestination
public typealias CDXcmAvailableAsset = SSFAssetManagmentStorage.CDXcmAvailableAsset
public typealias CDChainXcmConfig = SSFAssetManagmentStorage.CDChainXcmConfig
// Use local generated class for transaction history, not provided by storage module
