import Foundation
import SSFModels

enum UniversalWalletRegistry {
    static let bitcoinMainnetIndexerBaseURL = URL(string: "https://mempool.space/api")!
    static let bitcoinTestnetIndexerBaseURL = URL(string: "https://mempool.space/testnet/api")!
    static let bitcoinIconURL = URL(
        string: "https://bitcoin.org/img/icons/logotop.svg"
    )!
    static let legacyBitcoinIconURL = URL(
        string: "https://raw.githubusercontent.com/bitpay/bitcoin-brand/887f040f7c44660b84c4000f4a54897ba5518194/bitcoin.svg"
    )!

    static func isBitcoinIconURL(_ url: URL) -> Bool {
        url == bitcoinIconURL || url == legacyBitcoinIconURL
    }

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
            icon: bitcoinIconURL,
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
            name: "Mempool.space Public API",
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
            icon: bitcoinIconURL,
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
        features: ["receive"]
    )

    /// Taira is app-owned until the shared chains registry publishes a native
    /// Iroha row. These values are pinned to the public Taira profile in the
    /// reviewed `../iroha` `optimizations` revision `d8544f1d4d3a` and are
    /// revalidated against Torii before a balance is accepted.
    ///
    /// Taira's canonical XOR uses an unconstrained Iroha `NumericSpec`. The
    /// wallet's fixed-point adapter therefore uses Iroha's maximum permitted
    /// decimal scale so every valid wire quantity remains exact. The distinct
    /// scale-9 `xor#sora.universal` definition is discovered as a separate
    /// held asset and must never replace this native XOR identity.
    static let tairaNativeXorAssetDefinitionId = "6TEAJqbb8oEPmLncoNiMRbLEK6tw"
    static let tairaNativeXorAlias = "xor#universal"
    static let tairaNativeXorPrecision: UInt16 = 28
    static let tairaChainIconURL = URL(
        string: "https://raw.githubusercontent.com/soramitsu/shared-features-utils/master/icons/chains/white/SORA.svg"
    )!
    static let tairaXorIconURL = URL(
        string: "https://raw.githubusercontent.com/soramitsu/shared-features-utils/master/icons/tokens/coloured/XOR.svg"
    )!

    static let tairaChainModel: ChainModel = {
        let asset = AssetModel(
            id: tairaNativeXorAssetDefinitionId,
            name: "SORA XOR",
            symbol: "XOR",
            precision: tairaNativeXorPrecision,
            icon: tairaXorIconURL,
            currencyId: tairaNativeXorAlias,
            color: "2D75FF",
            isUtility: true,
            isNative: true,
            staking: nil,
            purchaseProviders: nil,
            type: nil,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: nil
        )
        let toriiNode = ChainNodeModel(
            url: taira.toriiBaseURL!,
            name: "Taira Torii",
            apikey: nil
        )
        let history = ChainModel.BlockExplorer(
            // History routing is selected by the canonical Iroha chain ID.
            // `subsquid` is only a persisted carrier accepted by SSFModels.
            type: "subsquid",
            url: taira.toriiBaseURL!
        )

        return ChainModel(
            rank: 2,
            disabled: false,
            chainId: taira.chainId,
            parentId: nil,
            paraId: nil,
            name: "Taira Testnet",
            assets: [asset],
            xcm: nil,
            nodes: [toriiNode],
            addressPrefix: 0,
            types: nil,
            icon: tairaChainIconURL,
            options: [.testnet],
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

    static let appOwnedProductionChains = [
        bitcoinMainnetChainModel,
        tairaChainModel
    ]

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
            features: ["transfer"],
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
        let nativeAsset: UniversalWalletRegistryAsset? = network == taira
            ? UniversalWalletRegistryAsset(
                id: tairaNativeXorAssetDefinitionId,
                symbol: "XOR",
                decimals: Int(tairaNativeXorPrecision),
                name: "SORA XOR"
            )
            : nil
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
            nativeAsset: nativeAsset,
            derivationPath: UniversalWalletDerivationPaths.irohaDefault,
            slip44CoinType: 617,
            features: network.features,
            endpoints: endpoints
        )
    }
}

enum UniversalWalletAccountProvisioning {
    static func addingAppOwnedAccounts(
        to wallet: MetaAccountModel,
        mnemonic: String
    ) throws -> MetaAccountModel {
        let bitcoinPublicKey = try BitcoinKeyDerivation.deriveAccount(
            mnemonic: mnemonic,
            network: .mainnet
        ).publicKey
        let tairaPublicKey = try IrohaKeyDerivation.deriveAccount(
            mnemonic: mnemonic
        ).publicKey
        let hasBitcoinAccount = try validateExistingAccount(
            in: wallet,
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            candidatePublicKey: bitcoinPublicKey,
            isStructurallyValid: {
                UniversalWalletChainAccountSupport.isValidBitcoinAccount($0)
            }
        )
        let hasTairaAccount = try validateExistingAccount(
            in: wallet,
            chainId: UniversalWalletRegistry.taira.chainId,
            candidatePublicKey: tairaPublicKey,
            isStructurallyValid: UniversalWalletChainAccountSupport.isValidTairaAccount
        )

        var updatedWallet = wallet
        if !hasBitcoinAccount {
            updatedWallet = try addingBitcoinMainnetAccount(
                to: updatedWallet,
                mnemonic: mnemonic
            )
        }
        if !hasTairaAccount {
            updatedWallet = try addingTairaTestnetAccount(
                to: updatedWallet,
                mnemonic: mnemonic
            )
        }

        return updatedWallet
    }

    private static func validateExistingAccount(
        in wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        candidatePublicKey: Data,
        isStructurallyValid: (ChainAccountModel) -> Bool
    ) throws -> Bool {
        let accounts = wallet.chainAccounts.filter {
            UniversalWalletChainAccountSupport.chainId($0.chainId, matches: chainId)
        }
        guard accounts.count <= 1 else {
            throw UniversalWalletRootRecoveryError.existingAccountUsesDifferentPhrase
        }
        guard let account = accounts.first else {
            return false
        }
        guard isStructurallyValid(account), account.publicKey == candidatePublicKey else {
            throw UniversalWalletRootRecoveryError.existingAccountUsesDifferentPhrase
        }

        return true
    }

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

    static func addingTairaTestnetAccount(
        to wallet: MetaAccountModel,
        mnemonic: String
    ) throws -> MetaAccountModel {
        let chainId = UniversalWalletRegistry.taira.chainId
        let account = try IrohaKeyDerivation.deriveAccount(mnemonic: mnemonic)
        let chainAccount = ChainAccountModel(
            chainId: chainId,
            accountId: account.publicKey,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue,
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
