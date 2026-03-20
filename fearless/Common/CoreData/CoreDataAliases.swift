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

        public class CDChain: CoreDataStubObject {}
        public class CDAsset: CoreDataStubObject {}
        public class CDChainAsset: CoreDataStubObject {}
        public class CDChainNode: CoreDataStubObject {}
        public class CDChainStorageItem: CoreDataStubObject {}
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
            @NSManaged public var autobalanced: NSNumber?
            @NSManaged public var issueMuted: NSNumber?
        }

        public class CDMetaAccount: CoreDataStubObject {
            @NSManaged public var metaId: String?
            @NSManaged public var substrateAccountId: String?
            @NSManaged public var substratePublicKey: Data?
            @NSManaged public var substrateCryptoType: NSNumber?
            @NSManaged public var ethereumAddress: String?
            @NSManaged public var ethereumPublicKey: Data?
            @NSManaged public var ethereumCryptoType: NSNumber?
            @NSManaged public var chainAccounts: NSSet?
        }

        public class CDChainAccount: CoreDataStubObject {
            @NSManaged public var accountId: Data?
            @NSManaged public var publicKey: Data?
            @NSManaged public var cryptoType: NSNumber?
            @NSManaged public var ethereumBased: NSNumber?
            @NSManaged public var chainId: String?
            @NSManaged public var metaAccount: CDMetaAccount?
        }

        public class CDAccountItem: CoreDataStubObject {}
        public class CDPolkaswapRemoteSettings: CoreDataStubObject {}
        public class CDPolkaswapDex: CoreDataStubObject {}
        public class CDPhishingItem: CoreDataStubObject {}
        public class CDScamInfo: CoreDataStubObject {}
        public class CDPriceData: CoreDataStubObject {}
        public class CDPriceProvider: CoreDataStubObject {}
        public class CDContactItem: CoreDataStubObject {}
        public class CDContact: CoreDataStubObject {}
        public class CDExternalApi: CoreDataStubObject {}
        public class CDXcmAvailableDestination: CoreDataStubObject {}
        public class CDXcmAvailableAsset: CoreDataStubObject {}
        public class CDChainXcmConfig: CoreDataStubObject {}
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
public typealias CDMetaAccount = SSFAssetManagmentStorage.CDMetaAccount
public typealias CDChainAccount = SSFAssetManagmentStorage.CDChainAccount
public typealias CDPolkaswapRemoteSettings = SSFAssetManagmentStorage.CDPolkaswapRemoteSettings
public typealias CDPhishingItem = SSFAssetManagmentStorage.CDPhishingItem
public typealias CDPriceData = SSFAssetManagmentStorage.CDPriceData
public typealias CDPriceProvider = SSFAssetManagmentStorage.CDPriceProvider
public typealias CDContactItem = SSFAssetManagmentStorage.CDContactItem
public typealias CDContact = SSFAssetManagmentStorage.CDContact
public typealias CDAccountItem = SSFAssetManagmentStorage.CDAccountItem
public typealias CDExternalApi = SSFAssetManagmentStorage.CDExternalApi
public typealias CDXcmAvailableDestination = SSFAssetManagmentStorage.CDXcmAvailableDestination
public typealias CDXcmAvailableAsset = SSFAssetManagmentStorage.CDXcmAvailableAsset
public typealias CDChainXcmConfig = SSFAssetManagmentStorage.CDChainXcmConfig
// Use local generated class for transaction history, not provided by storage module
