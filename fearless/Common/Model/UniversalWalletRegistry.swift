import Foundation

enum UniversalWalletRegistry {
    static let tairaChainId = "fc56984b-2be7-431d-840e-21514d1883f0"
    static let tairaXorAssetDefinitionId = "6TEAJqbb8oEPmLncoNiMRbLEK6tw"
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
        chainId: tairaChainId,
        chainDiscriminant: 369,
        toriiBaseURL: URL(string: "https://taira.sora.org")!,
        mcpPath: "/v1/mcp",
        enabledByDefault: true,
        features: ["transfer"],
        nativeAsset: IrohaNativeAsset(
            id: tairaXorAssetDefinitionId,
            symbol: "XOR",
            decimals: 9
        )
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
        let nativeAsset: IrohaNativeAsset?

        init(
            id: String,
            chainId: String,
            chainDiscriminant: Int,
            toriiBaseURL: URL?,
            mcpPath: String,
            enabledByDefault: Bool,
            features: [String],
            nativeAsset: IrohaNativeAsset? = nil
        ) {
            self.id = id
            self.chainId = chainId
            self.chainDiscriminant = chainDiscriminant
            self.toriiBaseURL = toriiBaseURL
            self.mcpPath = mcpPath
            self.enabledByDefault = enabledByDefault
            self.features = features
            self.nativeAsset = nativeAsset
        }

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

    struct IrohaNativeAsset: Equatable {
        let id: String
        let symbol: String
        let decimals: Int
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
            nativeAsset: network.nativeAsset.map { asset in
                UniversalWalletRegistryAsset(
                    id: asset.id,
                    symbol: asset.symbol,
                    decimals: asset.decimals,
                    name: asset.symbol
                )
            },
            derivationPath: UniversalWalletDerivationPaths.irohaDefault,
            slip44CoinType: 617,
            features: network.features,
            endpoints: endpoints
        )
    }
}
