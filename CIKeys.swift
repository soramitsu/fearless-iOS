import Foundation

private enum CIEnvironment {
    static func value(_ name: String) -> String {
        ProcessInfo.processInfo.environment[name] ?? ""
    }

    static func value(_ name: String, fallback fallbackName: String) -> String {
        let primary = value(name)
        return primary.isEmpty ? value(fallbackName) : primary
    }
}

enum MoonPayCIKeys {
    static var secretKey: String { CIEnvironment.value("MOONPAY_PRODUCTION_SECRET") }
    static var testSecretKey: String { CIEnvironment.value("MOONPAY_TEST_SECRET") }
}

enum SubscanCIKeys {
    static var apiKey: String { CIEnvironment.value("SUBSCAN_API_KEY") }
}

enum SoraCardCIKeys {
    static var apiKey: String { CIEnvironment.value("SORA_CARD_API_KEY") }
    static var domain: String { CIEnvironment.value("SORA_CARD_DOMAIN") }
    static var endpoint: String { CIEnvironment.value("SORA_CARD_KYC_ENDPOINT_URL") }
    static var username: String { CIEnvironment.value("SORA_CARD_KYC_USERNAME") }
    static var password: String { CIEnvironment.value("SORA_CARD_KYC_PASSWORD") }
}

enum PayWingsCIKeys {
    static var paywingsRepositoryUrl: String { CIEnvironment.value("PAY_WINGS_REPOSITORY_URL") }
    static var paywingsUsername: String { CIEnvironment.value("PAY_WINGS_USERNAME") }
    static var paywingsPassword: String { CIEnvironment.value("PAY_WINGS_PASSWORD") }
}

enum XOneCIKeys {
    static var x1EndpointUrlRelease: String { CIEnvironment.value("X1_ENDPOINT_URL_RELEASE") }
    static var x1WidgetIdRelease: String { CIEnvironment.value("X1_WIDGET_ID_RELEASE") }
    static var x1EndpointUrlDebug: String { CIEnvironment.value("X1_ENDPOINT_URL_DEBUG") }
    static var x1WidgetIdDebug: String { CIEnvironment.value("X1_WIDGET_ID_DEBUG") }
}

enum EthereumNodesApiKeys {
    static var ethereumApiKey: String { CIEnvironment.value("FL_BLAST_API_ETHEREUM_KEY") }
    static var bscApiKey: String { CIEnvironment.value("FL_BLAST_API_BSC_KEY") }
    static var sepoliaApiKey: String { CIEnvironment.value("FL_BLAST_API_SEPOLIA_KEY") }
    static var goerliApiKey: String { CIEnvironment.value("FL_BLAST_API_GOERLI_KEY") }
    static var polygonApiKey: String { CIEnvironment.value("FL_BLAST_API_POLYGON_KEY") }
}

enum EthereumNodesApiKeysDebug {
    static var ethereumApiKey: String {
        CIEnvironment.value("FL_BLAST_API_ETHEREUM_KEY_DEBUG", fallback: "FL_BLAST_API_ETHEREUM_KEY")
    }

    static var bscApiKey: String {
        CIEnvironment.value("FL_BLAST_API_BSC_KEY_DEBUG", fallback: "FL_BLAST_API_BSC_KEY")
    }

    static var sepoliaApiKey: String {
        CIEnvironment.value("FL_BLAST_API_SEPOLIA_KEY_DEBUG", fallback: "FL_BLAST_API_SEPOLIA_KEY")
    }

    static var goerliApiKey: String {
        CIEnvironment.value("FL_BLAST_API_GOERLI_KEY_DEBUG", fallback: "FL_BLAST_API_GOERLI_KEY")
    }

    static var polygonApiKey: String {
        CIEnvironment.value("FL_BLAST_API_POLYGON_KEY_DEBUG", fallback: "FL_BLAST_API_POLYGON_KEY")
    }
}

enum GoogleBackup {
    static var googleToken: String { CIEnvironment.value("WEB_CLIENT_ID_RELEASE") }
    static var googleUrlScheme: String { CIEnvironment.value("FEARLESS_GOOGLE_URL_SCHEME_RELEASE") }
}

enum GoogleBackupDebug {
    static var googleToken: String { CIEnvironment.value("WEB_CLIENT_ID_DEBUG") }
    static var googleUrlScheme: String { CIEnvironment.value("FEARLESS_GOOGLE_URL_SCHEME_DEBUG") }
}

enum WalletConnect {
    static var projectId: String { CIEnvironment.value("FL_WALLET_CONNECT_PROJECT_ID") }
}

enum WalletConnectDebug {
    static var projectId: String {
        CIEnvironment.value("FL_WALLET_CONNECT_PROJECT_ID_DEBUG", fallback: "FL_WALLET_CONNECT_PROJECT_ID")
    }
}

enum BlockExplorerApiKeys {
    static var etherscanApiKey: String { CIEnvironment.value("FL_IOS_ETHERSCAN_API_KEY") }
    static var polygonscanApiKey: String { CIEnvironment.value("FL_IOS_POLYGONSCAN_API_KEY") }
    static var bscscanApiKey: String { CIEnvironment.value("FL_IOS_BSCSCAN_API_KEY") }
    static var oklinkApiKey: String { CIEnvironment.value("FL_OKLINK_API_KEY") }
    static var opMainnetApiKey: String { CIEnvironment.value("FL_IOS_OPTIMISTIC_ETHERSCAN_API_KEY") }
}

enum BlockExplorerApiKeysDebug {
    static var etherscanApiKey: String { BlockExplorerApiKeys.etherscanApiKey }
    static var polygonscanApiKey: String { BlockExplorerApiKeys.polygonscanApiKey }
    static var bscscanApiKey: String { BlockExplorerApiKeys.bscscanApiKey }
    static var oklinkApiKey: String { BlockExplorerApiKeys.oklinkApiKey }
    static var opMainnetApiKey: String { BlockExplorerApiKeys.opMainnetApiKey }
}

enum ThirdPartyServicesApiKeys {
    static var alchemyApiKey: String { CIEnvironment.value("FL_IOS_ALCHEMY_API_ETHEREUM_KEY") }
}

enum ThirdPartyServicesApiKeysDebug {
    static var alchemyApiKey: String { ThirdPartyServicesApiKeys.alchemyApiKey }
}

enum DwellirNodeApiKey {
    static var dwellirApiKey: String { CIEnvironment.value("FL_DWELLIR_API_KEY") }
}

enum CoinbaseCIKeys {
    static var appId: String { CIEnvironment.value("COINBASE_APP_ID") }
}

enum TonNodeApiKey {
    static var tonApiKey: String { CIEnvironment.value("FL_TON_API_KEY") }
}

enum TonNodeApiKeyDebug {
    static var tonApiKey: String { CIEnvironment.value("FL_TON_API_KEY_DEBUG") }
}

enum OKXApiKeys {
    static var okxApiKey: String { CIEnvironment.value("FL_OKX_API_KEY") }
    static var okxSecretKey: String { CIEnvironment.value("FL_OKX_SECRET_KEY") }
    static var okxPassphrase: String { CIEnvironment.value("FL_OKX_PASSPHRASE") }
    static var okxProjectId: String { CIEnvironment.value("FL_OKX_PROJECT_ID") }
}

enum NomisApiKeys {
    static var nomisClientId: String { CIEnvironment.value("FL_NOMIS_CLIENT_ID") }
    static var nomisApiKey: String { CIEnvironment.value("FL_NOMIS_API_KEY") }
}
