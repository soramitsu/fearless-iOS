import Foundation
import WalletCore

/// Sample chain catalog: the networks the first release ships.
public enum PreviewCatalog {
    static let posix = Locale(identifier: "en_US_POSIX")

    /// Exact amount from a plain decimal string; zero if the literal is malformed.
    static func amount(_ text: String, _ decimals: Int) -> TokenAmount {
        TokenAmount(decimalString: text, decimals: decimals, locale: posix) ?? .zero(decimals: decimals)
    }

    private static func subscan(_ host: String) -> Explorer {
        Explorer(
            name: "Subscan",
            transactionURLTemplate: "https://\(host).subscan.io/extrinsic/{hash}",
            accountURLTemplate: "https://\(host).subscan.io/account/{address}"
        )
    }

    private static func etherscan(_ name: String, _ host: String) -> Explorer {
        Explorer(
            name: name,
            transactionURLTemplate: "https://\(host)/tx/{hash}",
            accountURLTemplate: "https://\(host)/address/{address}"
        )
    }

    public static let polkadot = Chain(
        id: "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
        name: "Polkadot", ecosystem: .substrate, isTestnet: false, ss58Prefix: 0,
        nativeAssetID: .native("91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"),
        explorer: subscan("polkadot"), iconName: "Polkadot", accentHex: "#E6007A", sortOrder: 0
    )
    public static let polkadotAssetHub = Chain(
        id: "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f",
        name: "Polkadot Asset Hub", ecosystem: .substrate, isTestnet: false, ss58Prefix: 0,
        nativeAssetID: .native("68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f"),
        explorer: subscan("assethub-polkadot"), iconName: "Assethub", accentHex: "#86198F", sortOrder: 1
    )
    public static let kusama = Chain(
        id: "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe",
        name: "Kusama", ecosystem: .substrate, isTestnet: false, ss58Prefix: 2,
        nativeAssetID: .native("b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"),
        explorer: subscan("kusama"), iconName: "Kusama", accentHex: "#2B2B33", sortOrder: 2
    )
    public static let kusamaAssetHub = Chain(
        id: "48239ef607d7928874027a43a67689209727dfb3d3dc5e5b03a39bdc2eda771a",
        name: "Kusama Asset Hub", ecosystem: .substrate, isTestnet: false, ss58Prefix: 2,
        nativeAssetID: .native("48239ef607d7928874027a43a67689209727dfb3d3dc5e5b03a39bdc2eda771a"),
        explorer: subscan("assethub-kusama"), iconName: "Assethub", accentHex: "#4B4B57", sortOrder: 3
    )
    public static let westend = Chain(
        id: "e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e",
        name: "Westend", ecosystem: .substrate, isTestnet: true, ss58Prefix: 42,
        nativeAssetID: .native("e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e"),
        explorer: subscan("westend"), iconName: "Westend", accentHex: "#DA68A7", sortOrder: 4
    )
    public static let ethereum = Chain(
        id: "eip155:1", name: "Ethereum", ecosystem: .evm, isTestnet: false, evmChainID: 1,
        nativeAssetID: .native("eip155:1"),
        explorer: etherscan("Etherscan", "etherscan.io"), iconName: "Ethereum", accentHex: "#627EEA", sortOrder: 5
    )
    public static let bnbSmartChain = Chain(
        id: "eip155:56", name: "BNB Smart Chain", ecosystem: .evm, isTestnet: false, evmChainID: 56,
        nativeAssetID: .native("eip155:56"),
        explorer: etherscan("BscScan", "bscscan.com"), iconName: "bnbchain", accentHex: "#C99400", sortOrder: 6
    )
    public static let polygon = Chain(
        id: "eip155:137", name: "Polygon", ecosystem: .evm, isTestnet: false, evmChainID: 137,
        nativeAssetID: .native("eip155:137"),
        explorer: etherscan("PolygonScan", "polygonscan.com"), iconName: "Polygon", accentHex: "#8247E5", sortOrder: 7
    )
    public static let sepolia = Chain(
        id: "eip155:11155111", name: "Sepolia", ecosystem: .evm, isTestnet: true, evmChainID: 11_155_111,
        nativeAssetID: .native("eip155:11155111"),
        explorer: etherscan("Etherscan", "sepolia.etherscan.io"), iconName: "Ethereum", accentHex: "#8A93B2", sortOrder: 8
    )

    public static let chains: [Chain] = [
        polkadot, polkadotAssetHub, kusama, kusamaAssetHub, westend, ethereum, bnbSmartChain, polygon, sepolia
    ]

    // MARK: Assets

    public static let dot = Asset(
        id: polkadot.nativeAssetID, symbol: "DOT", name: "Polkadot", decimals: 10, kind: .native,
        priceID: "polkadot", existentialDeposit: amount("1", 10), iconName: "Polkadot", tokenIconName: "DOT"
    )
    public static let dotAssetHub = Asset(
        id: polkadotAssetHub.nativeAssetID, symbol: "DOT", name: "Polkadot", decimals: 10, kind: .native,
        priceID: "polkadot", existentialDeposit: amount("0.01", 10), iconName: "Polkadot", tokenIconName: "DOT"
    )
    public static let usdtAssetHub = Asset(
        id: AssetID(chainID: polkadotAssetHub.id, key: "asset:1984"), symbol: "USDT", name: "Tether USD", decimals: 6,
        kind: .substrateAsset(id: "1984"), priceID: "tether", existentialDeposit: amount("0.01", 6), isStablecoin: true, tokenIconName: "USDT"
    )
    public static let usdcAssetHub = Asset(
        id: AssetID(chainID: polkadotAssetHub.id, key: "asset:1337"), symbol: "USDC", name: "USD Coin", decimals: 6,
        kind: .substrateAsset(id: "1337"), priceID: "usd-coin", existentialDeposit: amount("0.01", 6), isStablecoin: true, tokenIconName: "USDC"
    )
    public static let ksm = Asset(
        id: kusama.nativeAssetID, symbol: "KSM", name: "Kusama", decimals: 12, kind: .native,
        priceID: "kusama", existentialDeposit: amount("0.000333333333", 12), iconName: "Kusama", tokenIconName: "KSM"
    )
    public static let ksmAssetHub = Asset(
        id: kusamaAssetHub.nativeAssetID, symbol: "KSM", name: "Kusama", decimals: 12, kind: .native,
        priceID: "kusama", existentialDeposit: amount("0.000003333333", 12), iconName: "Kusama", tokenIconName: "KSM"
    )
    public static let usdtKusamaAssetHub = Asset(
        id: AssetID(chainID: kusamaAssetHub.id, key: "asset:1984"), symbol: "USDT", name: "Tether USD", decimals: 6,
        kind: .substrateAsset(id: "1984"), priceID: "tether", existentialDeposit: amount("0.001", 6), isStablecoin: true, tokenIconName: "USDT"
    )
    public static let wnd = Asset(
        id: westend.nativeAssetID, symbol: "WND", name: "Westend", decimals: 12, kind: .native,
        priceID: nil, existentialDeposit: amount("0.01", 12), iconName: "Westend", tokenIconName: "WND"
    )
    public static let eth = Asset(
        id: ethereum.nativeAssetID, symbol: "ETH", name: "Ether", decimals: 18, kind: .native,
        priceID: "ethereum", iconName: "Ethereum", tokenIconName: "ETH"
    )
    public static let usdtEthereum = Asset(
        id: AssetID(chainID: ethereum.id, key: "erc20:0xdAC17F958D2ee523a2206206994597C13D831ec7"), symbol: "USDT", name: "Tether USD",
        decimals: 6, kind: .erc20(contract: "0xdAC17F958D2ee523a2206206994597C13D831ec7"), priceID: "tether", isStablecoin: true, tokenIconName: "USDT"
    )
    public static let usdcEthereum = Asset(
        id: AssetID(chainID: ethereum.id, key: "erc20:0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"), symbol: "USDC", name: "USD Coin",
        decimals: 6, kind: .erc20(contract: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"), priceID: "usd-coin", isStablecoin: true, tokenIconName: "USDC"
    )
    public static let bnb = Asset(
        id: bnbSmartChain.nativeAssetID, symbol: "BNB", name: "BNB", decimals: 18, kind: .native,
        priceID: "binancecoin", iconName: "bnbchain", tokenIconName: "BNB"
    )
    public static let pol = Asset(
        id: polygon.nativeAssetID, symbol: "POL", name: "Polygon", decimals: 18, kind: .native,
        priceID: "polygon-ecosystem-token", iconName: "Polygon", tokenIconName: "POL"
    )
    public static let sepoliaETH = Asset(
        id: sepolia.nativeAssetID, symbol: "ETH", name: "Sepolia Ether", decimals: 18, kind: .native,
        priceID: nil, iconName: "Ethereum", tokenIconName: "ETH"
    )

    public static let assets: [Asset] = [
        dot, dotAssetHub, usdtAssetHub, usdcAssetHub, ksm, ksmAssetHub, usdtKusamaAssetHub, wnd,
        eth, usdtEthereum, usdcEthereum, bnb, pol, sepoliaETH
    ]

    static func chain(_ id: ChainID) -> Chain? {
        chains.first { $0.id == id }
    }

    static func asset(_ id: AssetID) -> Asset? {
        assets.first { $0.id == id }
    }

    // MARK: Nodes

    /// Sample endpoints. The preview never connects to them.
    static func defaultNodes(for chainID: ChainID) -> [ChainNode] {
        func node(_ name: String, _ url: String) -> ChainNode? {
            URL(string: url).map { ChainNode(name: name, url: $0, isCustom: false) }
        }
        let list: [ChainNode?]
        switch chainID {
        case polkadot.id:
            list = [node("Parity", "wss://rpc.polkadot.io"), node("IBP 1", "wss://rpc.ibp.network/polkadot"), node("Dwellir", "wss://polkadot-rpc.n.dwellir.com")]
        case polkadotAssetHub.id:
            list = [node("Parity", "wss://polkadot-asset-hub-rpc.polkadot.io"), node("IBP 1", "wss://sys.ibp.network/asset-hub-polkadot")]
        case kusama.id:
            list = [node("Parity", "wss://kusama-rpc.polkadot.io"), node("IBP 1", "wss://rpc.ibp.network/kusama")]
        case kusamaAssetHub.id:
            list = [node("Parity", "wss://kusama-asset-hub-rpc.polkadot.io"), node("IBP 1", "wss://sys.ibp.network/asset-hub-kusama")]
        case westend.id:
            list = [node("Parity", "wss://westend-rpc.polkadot.io")]
        case ethereum.id:
            list = [node("PublicNode", "https://ethereum-rpc.publicnode.com"), node("LlamaNodes", "https://eth.llamarpc.com")]
        case bnbSmartChain.id:
            list = [node("BNB Chain", "https://bsc-dataseed.bnbchain.org"), node("PublicNode", "https://bsc-rpc.publicnode.com")]
        case polygon.id:
            list = [node("PublicNode", "https://polygon-bor-rpc.publicnode.com"), node("Polygon", "https://polygon-rpc.com")]
        case sepolia.id:
            list = [node("PublicNode", "https://ethereum-sepolia-rpc.publicnode.com")]
        default:
            list = []
        }
        return list.compactMap { $0 }
    }
}
