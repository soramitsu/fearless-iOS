import Foundation
import SSFModels

enum UniversalWalletRegistry {
    static let bitcoinMainnetIndexerBaseURL = URL(string: "https://blockstream.info/api")!
    static let bitcoinTestnetIndexerBaseURL = URL(string: "https://blockstream.info/testnet/api")!
    static let tonIndexerBaseURL = URL(string: "https://ti.soramitsu.io")!
    static let tonNativeAssetId = TonConstants.tonAssetId
    static let solanaIndexerBaseURL = URL(string: "https://si.soramitsu.io")!
    static let solanaMainnetRPCURL = URL(string: "https://api.mainnet-beta.solana.com")!
    static let solanaDevnetRPCURL = URL(string: "https://api.devnet.solana.com")!

    static let bitcoinMainnet = BitcoinNetwork(
        id: "bitcoin-mainnet",
        chainId: "bitcoin:mainnet",
        name: "Bitcoin",
        slip44CoinType: 0,
        addressHrp: "bc",
        accountPath: UniversalWalletDerivationPaths.bitcoinMainnetAccount,
        firstReceivePath: UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive,
        indexerBaseURL: bitcoinMainnetIndexerBaseURL,
        defaultGapLimit: 20,
        enabledByDefault: true,
        nativeAsset: BitcoinNativeAsset(
            id: "BTC",
            symbol: "BTC",
            decimals: 8
        )
    )

    /// Bitcoin is an app-owned network. It is intentionally merged into the
    /// downloaded registry at runtime because the shared Substrate/EVM
    /// registry does not publish a Bitcoin row.
    static let bitcoinMainnetChainModel: ChainModel = {
        let asset = AssetModel(
            id: bitcoinMainnet.nativeAsset.id,
            name: bitcoinMainnet.name,
            symbol: bitcoinMainnet.nativeAsset.symbol,
            precision: UInt16(bitcoinMainnet.nativeAsset.decimals),
            icon: nil,
            currencyId: bitcoinMainnet.nativeAsset.id,
            color: "F7931A",
            isUtility: true,
            isNative: true,
            staking: nil,
            purchaseProviders: nil,
            type: nil,
            ethereumType: nil,
            priceProvider: PriceProvider(
                type: .coingecko,
                id: "bitcoin",
                precision: nil
            ),
            coingeckoPriceId: "bitcoin"
        )
        let indexerNode = ChainNodeModel(
            url: bitcoinMainnet.indexerBaseURL,
            name: "Blockstream Esplora",
            apikey: nil
        )
        let history = ChainModel.BlockExplorer(
            type: "subsquid",
            url: bitcoinMainnet.indexerBaseURL
        )

        return ChainModel(
            rank: 1,
            disabled: false,
            chainId: bitcoinMainnet.chainId,
            parentId: nil,
            paraId: nil,
            name: bitcoinMainnet.name,
            assets: [asset],
            xcm: nil,
            nodes: [indexerNode],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: ChainModel.ExternalApiSet(
                staking: nil,
                history: history,
                crowdloans: nil,
                explorers: nil
            ),
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }()

    static let appOwnedProductionChains = [bitcoinMainnetChainModel]

    static let bitcoinTestnet = BitcoinNetwork(
        id: "bitcoin-testnet",
        chainId: "bitcoin:testnet",
        name: "Bitcoin Testnet",
        slip44CoinType: 1,
        addressHrp: "tb",
        accountPath: UniversalWalletDerivationPaths.bitcoinTestnetAccount,
        firstReceivePath: UniversalWalletDerivationPaths.bitcoinTestnetFirstReceive,
        indexerBaseURL: bitcoinTestnetIndexerBaseURL,
        defaultGapLimit: 20,
        enabledByDefault: false,
        nativeAsset: BitcoinNativeAsset(
            id: "BTC",
            symbol: "BTC",
            decimals: 8
        )
    )

    static func bitcoinNetwork(for chainId: String) -> BitcoinNetwork? {
        switch chainId.lowercased() {
        case bitcoinMainnet.chainId, bitcoinMainnet.id:
            return bitcoinMainnet
        case bitcoinTestnet.chainId, bitcoinTestnet.id:
            return bitcoinTestnet
        default:
            return nil
        }
    }

    static let solanaMainnet = SolanaNetwork(
        id: "solana-mainnet",
        chainId: "solana:mainnet",
        name: "Solana",
        indexerBaseURL: solanaIndexerBaseURL,
        rpcURL: solanaMainnetRPCURL,
        enabledByDefault: true,
        nativeAsset: SolanaNativeAsset(
            id: "SOL",
            symbol: "SOL",
            decimals: 9
        )
    )

    static let solanaDevnet = SolanaNetwork(
        id: "solana-devnet",
        chainId: "solana:devnet",
        name: "Solana Devnet",
        indexerBaseURL: solanaIndexerBaseURL,
        rpcURL: solanaDevnetRPCURL,
        enabledByDefault: false,
        nativeAsset: SolanaNativeAsset(
            id: "SOL",
            symbol: "SOL",
            decimals: 9
        )
    )

    static let taira = IrohaNetwork(
        id: "taira-testnet",
        chainId: "iroha3-taira",
        chainDiscriminant: 369,
        toriiBaseURL: URL(string: "https://taira.sora.org")!,
        mcpPath: "/v1/mcp",
        enabledByDefault: true,
        features: ["transfer"]
    )

    static let nexus = IrohaNetwork(
        id: "sora-nexus-mainnet",
        chainId: "sora:nexus:global",
        chainDiscriminant: 753,
        toriiBaseURL: URL(string: "https://minamoto.sora.org")!,
        mcpPath: "/v1/mcp",
        enabledByDefault: false,
        features: ["transfer", "offline-cash", "sccp", "governance"]
    )

    static let bitcoinMainnetRegistryEntry = makeBitcoinRegistryEntry(bitcoinMainnet)
    static let bitcoinTestnetRegistryEntry = makeBitcoinRegistryEntry(bitcoinTestnet)
    static let tonMainnetRegistryEntry = UniversalWalletChainRegistryEntry(
        id: "ton-mainnet",
        ecosystem: .ton,
        chainId: "ton:mainnet",
        displayName: "TON",
        enabledByDefault: true,
        nativeAsset: UniversalWalletRegistryAsset(
            id: "TON",
            symbol: "TON",
            decimals: 9,
            name: "Toncoin"
        ),
        derivationPath: UniversalWalletDerivationPaths.tonDefault,
        slip44CoinType: 607,
        endpoints: [
            UniversalWalletRegistryEndpoint(
                id: "ton-mainnet-indexer",
                kind: .indexer,
                url: tonIndexerBaseURL.absoluteString,
                readOnly: true
            )
        ]
    )
    static let solanaMainnetRegistryEntry = makeSolanaRegistryEntry(
        solanaMainnet,
        derivationPath: UniversalWalletDerivationPaths.solanaDefault,
        slip44CoinType: 501
    )
    static let solanaDevnetRegistryEntry = makeSolanaRegistryEntry(
        solanaDevnet,
        derivationPath: UniversalWalletDerivationPaths.solanaDefault,
        slip44CoinType: 501
    )
    static let tairaRegistryEntry = makeIrohaRegistryEntry(taira, displayName: "Taira Testnet")
    static let nexusRegistryEntry = makeIrohaRegistryEntry(nexus, displayName: "SORA Nexus")
    static let chainRegistry = UniversalWalletChainRegistry(
        chains: [
            bitcoinMainnetRegistryEntry,
            bitcoinTestnetRegistryEntry,
            tonMainnetRegistryEntry,
            solanaMainnetRegistryEntry,
            solanaDevnetRegistryEntry,
            tairaRegistryEntry,
            nexusRegistryEntry
        ]
    )

    struct IrohaNetwork: Equatable {
        let id: String
        let chainId: String
        let chainDiscriminant: Int
        let toriiBaseURL: URL?
        let mcpPath: String
        let enabledByDefault: Bool
        let features: [String]

        var mcpEndpointURL: URL? {
            guard let toriiBaseURL = toriiBaseURL else {
                return nil
            }

            return mcpPath
                .split(separator: "/")
                .reduce(toriiBaseURL) { url, component in
                    url.appendingPathComponent(String(component))
                }
        }
    }

    struct BitcoinNetwork: Equatable {
        let id: String
        let chainId: String
        let name: String
        let slip44CoinType: Int
        let addressHrp: String
        let accountPath: String
        let firstReceivePath: String
        let indexerBaseURL: URL
        let defaultGapLimit: Int
        let enabledByDefault: Bool
        let nativeAsset: BitcoinNativeAsset
    }

    struct BitcoinNativeAsset: Equatable {
        let id: String
        let symbol: String
        let decimals: Int
    }

    struct SolanaNetwork: Equatable {
        let id: String
        let chainId: String
        let name: String
        let indexerBaseURL: URL
        let rpcURL: URL
        let enabledByDefault: Bool
        let nativeAsset: SolanaNativeAsset
    }

    struct SolanaNativeAsset: Equatable {
        let id: String
        let symbol: String
        let decimals: Int
    }

    private static func makeBitcoinRegistryEntry(_ network: BitcoinNetwork) -> UniversalWalletChainRegistryEntry {
        UniversalWalletChainRegistryEntry(
            id: network.id,
            ecosystem: .bitcoin,
            chainId: network.chainId,
            displayName: network.name,
            enabledByDefault: network.enabledByDefault,
            nativeAsset: UniversalWalletRegistryAsset(
                id: network.nativeAsset.id,
                symbol: network.nativeAsset.symbol,
                decimals: network.nativeAsset.decimals,
                name: network.name
            ),
            derivationPath: network.accountPath,
            slip44CoinType: network.slip44CoinType,
            endpoints: [
                UniversalWalletRegistryEndpoint(
                    id: "\(network.id)-indexer",
                    kind: .indexer,
                    url: network.indexerBaseURL.absoluteString,
                    readOnly: true
                )
            ]
        )
    }

    private static func makeSolanaRegistryEntry(
        _ network: SolanaNetwork,
        derivationPath: String,
        slip44CoinType: Int
    ) -> UniversalWalletChainRegistryEntry {
        UniversalWalletChainRegistryEntry(
            id: network.id,
            ecosystem: .solana,
            chainId: network.chainId,
            displayName: network.name,
            enabledByDefault: network.enabledByDefault,
            nativeAsset: UniversalWalletRegistryAsset(
                id: network.nativeAsset.id,
                symbol: network.nativeAsset.symbol,
                decimals: network.nativeAsset.decimals,
                name: network.name
            ),
            derivationPath: derivationPath,
            slip44CoinType: slip44CoinType,
            endpoints: [
                UniversalWalletRegistryEndpoint(
                    id: "\(network.id)-indexer",
                    kind: .indexer,
                    url: network.indexerBaseURL.absoluteString,
                    readOnly: true
                ),
                UniversalWalletRegistryEndpoint(
                    id: "\(network.id)-rpc",
                    kind: .rpc,
                    url: network.rpcURL.absoluteString,
                    readOnly: false,
                    priority: 1
                )
            ]
        )
    }

    private static func makeIrohaRegistryEntry(
        _ network: IrohaNetwork,
        displayName: String
    ) -> UniversalWalletChainRegistryEntry {
        let endpoints = network.mcpEndpointURL.map { endpoint in
            [
                UniversalWalletRegistryEndpoint(
                    id: "\(network.id)-torii-mcp",
                    kind: .toriiMcp,
                    url: endpoint.absoluteString,
                    readOnly: false
                )
            ]
        } ?? []

        return UniversalWalletChainRegistryEntry(
            id: network.id,
            ecosystem: .iroha,
            chainId: network.chainId,
            displayName: displayName,
            enabledByDefault: network.enabledByDefault,
            derivationPath: UniversalWalletDerivationPaths.irohaDefault,
            slip44CoinType: 617,
            features: network.features,
            endpoints: endpoints
        )
    }
}

enum UniversalWalletAccountProvisioning {
    static func addingBitcoinMainnetAccount(
        to wallet: MetaAccountModel,
        mnemonic: String
    ) throws -> MetaAccountModel {
        let chainId = UniversalWalletRegistry.bitcoinMainnet.chainId
        let account = try BitcoinKeyDerivation.deriveAccount(
            mnemonic: mnemonic,
            network: .mainnet
        )
        let chainAccount = ChainAccountModel(
            chainId: chainId,
            accountId: account.publicKey,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ecdsa.rawValue,
            ethereumBased: false
        )

        var chainAccounts = wallet.chainAccounts.filter {
            !UniversalWalletChainAccountSupport.chainId($0.chainId, matches: chainId)
        }
        chainAccounts.insert(chainAccount)

        guard chainAccounts != wallet.chainAccounts else {
            return wallet
        }

        return wallet.replacingChainAccounts(chainAccounts)
    }
}
