#if !canImport(SSFAssetManagmentStorage)
    import Foundation
    import CoreData

    public enum SSFAssetManagmentStorage {
        public class CDChain: NSManagedObject {}
        public class CDAsset: NSManagedObject {}
        public class CDChainAsset: NSManagedObject {}
        public class CDChainNode: NSManagedObject {}
        public class CDChainStorageItem: NSManagedObject {}
        public class CDRuntimeMetadataItem: NSManagedObject {}
        public class CDAccountInfo: NSManagedObject {}
        public class CDStashItem: NSManagedObject {}
        public class CDSingleValue: NSManagedObject {}
        public class CDChainSettings: NSManagedObject {}
        public class CDMetaAccount: NSManagedObject {}
        public class CDChainAccount: NSManagedObject {}
        public class CDPolkaswapRemoteSettings: NSManagedObject {}
        public class CDPolkaswapDex: NSManagedObject {}
        public class CDPhishingItem: NSManagedObject {}
        public class CDScamInfo: NSManagedObject {}
        public class CDPriceData: NSManagedObject {}
        public class CDPriceProvider: NSManagedObject {}
        public class CDContactItem: NSManagedObject {}
        public class CDContact: NSManagedObject {}
        public class CDExternalApi: NSManagedObject {}
        public class CDXcmAvailableDestination: NSManagedObject {}
        public class CDXcmAvailableAsset: NSManagedObject {}
        public class CDChainXcmConfig: NSManagedObject {}
    }
#endif
