import Foundation

#if !canImport(FearlessKeys)
    // Fallback shims to allow building without the private FearlessKeys pod/module.
    // Values are empty by default to avoid leaking secrets in PR builds.

    public enum ThirdPartyServicesApiKeys {
        public static let alchemyApiKey: String = ""
    }

    public enum ThirdPartyServicesApiKeysDebug {
        public static let alchemyApiKey: String = ""
    }

    public enum BlockExplorerApiKeys {
        public static let oklinkApiKey: String = ""
    }

    public enum BlockExplorerApiKeysDebug {
        public static let oklinkApiKey: String = ""
    }
#endif
