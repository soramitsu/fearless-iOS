import Foundation
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#else
    import CoreData
    import RobinHood

    // Runtime-compatible fallback for the unavailable SSFAssetManagmentStorage
    // product. Objective-C names and managed properties must stay aligned with
    // SubstrateDataModel_v8 so existing stores materialize the expected types.
    public enum SSFAssetManagmentStorageStub {
        public enum CodingError: LocalizedError {
            case unsupportedEntity(String)

            public var errorDescription: String? {
                switch self {
                case let .unsupportedEntity(entityName):
                    return "Core Data coding is unavailable for \(entityName)"
                }
            }
        }

        open class CoreDataStubObject: NSManagedObject, CoreDataCodable {
            open func populate(from _: Decoder, using _: NSManagedObjectContext) throws {
                throw CodingError.unsupportedEntity(entity.name ?? String(describing: type(of: self)))
            }

            open func encode(to _: Encoder) throws {
                throw CodingError.unsupportedEntity(entity.name ?? String(describing: type(of: self)))
            }
        }

        @objc(CDChain)
        public class CDChain: CoreDataStubObject {
            @NSManaged public var rank: String?
            @NSManaged public var disabled: Bool
            @NSManaged public var chainId: String?
            @NSManaged public var parentId: String?
            @NSManaged public var name: String?
            @NSManaged public var types: URL?
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
            @NSManaged public var pricingApiType: String?
            @NSManaged public var pricingApiUrl: URL?
            @NSManaged public var identityChain: String?
            @NSManaged public var paraId: String?
            @NSManaged public var isOrml: Bool
            @NSManaged public var xcmConfig: CDChainXcmConfig?
            @NSManaged public var explorers: NSSet?
        }

        @objc(CDAsset)
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
            @NSManaged public var chain: CDChain?
            @NSManaged public var priceData: NSSet?
        }

        public class CDChainAsset: CoreDataStubObject {}
        @objc(CDChainNode)
        public class CDChainNode: CoreDataStubObject {
            @NSManaged public var url: URL?
            @NSManaged public var name: String?
            @NSManaged public var apiKeyName: String?
            @NSManaged public var apiQueryName: String?
            @NSManaged public var chain: CDChain?
        }

        @objc(CDChainStorageItem)
        public class CDChainStorageItem: CoreDataStubObject {
            @NSManaged public var identifier: String?
            @NSManaged public var data: Data?

            override public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
                let container = try decoder.container(keyedBy: ChainStorageItem.CodingKeys.self)

                identifier = try container.decode(String.self, forKey: .identifier)
                data = try container.decode(Data.self, forKey: .data)
            }

            override public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: ChainStorageItem.CodingKeys.self)

                try container.encodeIfPresent(identifier, forKey: .identifier)
                try container.encodeIfPresent(data, forKey: .data)
            }
        }

        @objc(CDRuntimeMetadataItem)
        public class CDRuntimeMetadataItem: CoreDataStubObject {
            private enum CodingKeys: String, CodingKey {
                case chain
                case version
                case txVersion
                case metadata
            }

            @NSManaged public var identifier: String?
            @NSManaged public var metadata: Data?
            @NSManaged public var resolver: Data?
            @NSManaged public var txVersion: Int32
            @NSManaged public var version: Int32

            override public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                identifier = try container.decode(String.self, forKey: .chain)
                metadata = try container.decode(Data.self, forKey: .metadata)
                version = Int32(bitPattern: try container.decode(UInt32.self, forKey: .version))
                txVersion = Int32(bitPattern: try container.decode(UInt32.self, forKey: .txVersion))
            }

            override public func encode(to encoder: Encoder) throws {
                guard let identifier, let metadata else {
                    return
                }

                var container = encoder.container(keyedBy: CodingKeys.self)

                try container.encode(identifier, forKey: .chain)
                try container.encode(UInt32(bitPattern: version), forKey: .version)
                try container.encode(UInt32(bitPattern: txVersion), forKey: .txVersion)
                try container.encode(metadata, forKey: .metadata)
            }
        }

        public class CDAccountInfo: CoreDataStubObject {
            @NSManaged public var identifier: String?
        }

        @objc(CDStashItem)
        public class CDStashItem: CoreDataStubObject {
            @NSManaged public var stash: String?
            @NSManaged public var controller: String?

            override public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
                let stashItem = try StashItem(from: decoder)

                stash = stashItem.stash
                controller = stashItem.controller
            }

            override public func encode(to encoder: Encoder) throws {
                guard let stash, let controller else {
                    return
                }

                try StashItem(stash: stash, controller: controller).encode(to: encoder)
            }
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
        @objc(CDPolkaswapRemoteSettings)
        public class CDPolkaswapRemoteSettings: CoreDataStubObject {
            @NSManaged public var version: String?
            @NSManaged public var availableSources: [String]?
            @NSManaged public var forceSmartIds: [String]?
            @NSManaged public var availableDexIds: NSSet?
            @NSManaged public var xstusdId: String?
        }

        @objc(CDPolkaswapDex)
        public class CDPolkaswapDex: CoreDataStubObject {
            @NSManaged public var name: String?
            @NSManaged public var code: Int32
            @NSManaged public var assetId: String?
        }

        @objc(CDPhishingItem)
        public class CDPhishingItem: CoreDataStubObject {
            @NSManaged public var identifier: String?
            @NSManaged public var publicKey: String?
            @NSManaged public var source: String?

            override public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
                let phishingItem = try PhishingItem(from: decoder)

                identifier = phishingItem.identifier
                source = phishingItem.source
                publicKey = phishingItem.publicKey
            }

            override public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: PhishingItem.CodingKeys.self)

                try container.encode(source, forKey: .source)
                try container.encode(publicKey, forKey: .publicKey)
            }
        }

        @objc(CDScamInfo)
        public class CDScamInfo: CoreDataStubObject {
            @NSManaged public var address: String?
            @NSManaged public var name: String?
            @NSManaged public var subtype: String?
            @NSManaged public var type: String?

            override public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
                let container = try decoder.container(keyedBy: ScamInfo.CodingKeys.self)

                name = try container.decode(String.self, forKey: .name)
                address = try container.decode(String.self, forKey: .address)
                type = try container.decode(String.self, forKey: .type)
                subtype = try container.decode(String.self, forKey: .subtype)
            }

            override public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: ScamInfo.CodingKeys.self)

                try container.encode(name, forKey: .name)
                try container.encode(address, forKey: .address)
                try container.encode(type, forKey: .type)
                try container.encode(subtype, forKey: .subtype)
            }
        }

        @objc(CDPriceData)
        public class CDPriceData: CoreDataStubObject {
            @NSManaged public var coingeckoPriceId: String?
            @NSManaged public var currencyId: String?
            @NSManaged public var fiatDayByChange: String?
            @NSManaged public var price: String?
            @NSManaged public var priceId: String?
            @NSManaged public var asset: CDAsset?
        }

        @objc(CDPriceProvider)
        public class CDPriceProvider: CoreDataStubObject {
            @NSManaged public var type: String?
            @NSManaged public var id: String?
            @NSManaged public var precision: String?
            @NSManaged public var asset: CDAsset?
        }

        @objc(CDContactItem)
        public class CDContactItem: CoreDataStubObject {
            @NSManaged public var identifier: String?
            @NSManaged public var peerAddress: String?
            @NSManaged public var peerName: String?
            @NSManaged public var targetAddress: String?
            @NSManaged public var updatedAt: Int64

            override public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
                let contact = try ContactItem(from: decoder)

                identifier = contact.identifier
                peerAddress = contact.peerAddress
                peerName = contact.peerName
                targetAddress = contact.targetAddress
                updatedAt = contact.updatedAt
            }

            override public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: ContactItem.CodingKeys.self)

                try container.encodeIfPresent(peerAddress, forKey: .peerAddress)
                try container.encodeIfPresent(peerName, forKey: .peerName)
                try container.encodeIfPresent(targetAddress, forKey: .targetAddress)
                try container.encode(updatedAt, forKey: .updatedAt)
            }
        }

        @objc(CDContact)
        public class CDContact: CoreDataStubObject {
            @NSManaged public var address: String?
            @NSManaged public var chainId: String?
            @NSManaged public var name: String?

            override public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
                let container = try decoder.container(keyedBy: Contact.CodingKeys.self)

                name = try container.decode(String.self, forKey: .name)
                address = try container.decode(String.self, forKey: .address)
                chainId = try container.decode(String.self, forKey: .chainId)
            }

            override public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: Contact.CodingKeys.self)

                try container.encode(name, forKey: .name)
                try container.encode(address, forKey: .address)
                try container.encode(chainId, forKey: .chainId)
            }
        }

        public class CDCurrency: CoreDataStubObject {
            @NSManaged public var id: String?
            @NSManaged public var symbol: String?
            @NSManaged public var name: String?
            @NSManaged public var icon: String?
            @NSManaged public var isSelected: Bool
        }

        @objc(CDExternalApi)
        public class CDExternalApi: CoreDataStubObject {
            @NSManaged public var type: String?
            @NSManaged public var types: NSArray?
            @NSManaged public var url: String?
            @NSManaged public var chain: CDChain?
        }

        @objc(CDXcmAvailableDestination)
        public class CDXcmAvailableDestination: CoreDataStubObject {
            @NSManaged public var chainId: String?
            @NSManaged public var bridgeParachainId: String?
            @NSManaged public var assets: NSSet?
            @NSManaged public var config: CDChainXcmConfig?
        }

        @objc(CDXcmAvailableAsset)
        public class CDXcmAvailableAsset: CoreDataStubObject {
            @NSManaged public var id: String?
            @NSManaged public var minAmount: String?
            @NSManaged public var symbol: String?
        }

        @objc(CDChainXcmConfig)
        public class CDChainXcmConfig: CoreDataStubObject {
            @NSManaged public var xcmVersion: String?
            @NSManaged public var destWeightIsPrimitive: Bool
            @NSManaged public var availableAssets: NSSet?
            @NSManaged public var availableDestinations: NSSet?
            @NSManaged public var chain: CDChain?
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
public typealias CDStashItem = SSFAssetManagmentStorage.CDStashItem
#if canImport(SSFSingleValueCache)
    public typealias CDSingleValue = SSFSingleValueCache.CDSingleValue
#else
    public typealias CDSingleValue = SSFAssetManagmentStorage.CDSingleValue
#endif
#if canImport(SSFAccountManagmentStorage)
    public typealias CDAccountInfo = SSFAccountManagmentStorage.CDAccountInfo
    public typealias CDChainSettings = SSFAccountManagmentStorage.CDChainSettings
    public typealias CDAssetVisibility = SSFAccountManagmentStorage.CDAssetVisibility
    public typealias CDMetaAccount = SSFAccountManagmentStorage.CDMetaAccount
    public typealias CDChainAccount = SSFAccountManagmentStorage.CDChainAccount
    public typealias CDCustomChainNode = SSFAccountManagmentStorage.CDCustomChainNode
    public typealias CDCurrency = SSFAccountManagmentStorage.CDCurrency
#else
    public typealias CDAccountInfo = SSFAssetManagmentStorage.CDAccountInfo
    public typealias CDChainSettings = SSFAssetManagmentStorage.CDChainSettings
    public typealias CDAssetVisibility = SSFAssetManagmentStorage.CDAssetVisibility
    public typealias CDMetaAccount = SSFAssetManagmentStorage.CDMetaAccount
    public typealias CDChainAccount = SSFAssetManagmentStorage.CDChainAccount
    public typealias CDCustomChainNode = SSFAssetManagmentStorage.CDCustomChainNode
    public typealias CDCurrency = SSFAssetManagmentStorage.CDCurrency
#endif
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
