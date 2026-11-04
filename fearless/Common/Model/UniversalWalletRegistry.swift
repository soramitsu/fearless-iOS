import Foundation
import SSFModels

enum UniversalWalletRegistry {
    static let bitcoinMainnetIndexerBaseURL = URL(string: "https://mempool.space/api")!
    static let bitcoinTestnetIndexerBaseURL = URL(string: "https://mempool.space/testnet/api")!
    /// A second public Esplora service. Balances, fee estimates and broadcasts fail over to it
    /// when mempool.space is unreachable or rate limits the app.
    static let bitcoinMainnetFallbackIndexerBaseURL = URL(string: "https://blockstream.info/api")!
    static let bitcoinTestnetFallbackIndexerBaseURL = URL(string: "https://blockstream.info/testnet/api")!
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
    /// The SORA Solana indexer. It serves Solana testnet and has no `/service-info`, so the
    /// wallet never uses it for mainnet balances, fees, simulation or broadcast; mainnet reads
    /// go straight to JSON-RPC (`solanaMainnetRPCURLs`).
    static let solanaIndexerBaseURL = URL(string: "https://si.soramitsu.io")!
    static let solanaMainnetRPCURL = URL(string: "https://api.mainnet-beta.solana.com")!
    /// Public mainnet JSON-RPC nodes in the order the wallet asks them. Reads, fees,
    /// simulation and broadcasts fail over down this list; a build may put its own provider in
    /// front of it (`SolanaRpcEndpoints.configuredProviderURL`). Checked 2026-10-11: the first
    /// two answer `getHealth`; solana.drpc.org (used by the extension) refuses free-plan Solana
    /// requests and ankr requires a key, so neither is listed. publicnode refuses
    /// `getTokenAccountsByOwner`; public.rpc.solanavibestation.com serves it for both token
    /// programs without a key (checked 2026-10-24) but answers only about two requests a second
    /// per address, so the wallet spaces its requests to it (`SolanaRpcEndpoints.requestSpacing`).
    static let solanaMainnetRPCURLs = [
        solanaMainnetRPCURL,
        URL(string: "https://solana-rpc.publicnode.com")!,
        URL(string: "https://public.rpc.solanavibestation.com")!
    ]
    static let solanaDevnetRPCURL = URL(string: "https://api.devnet.solana.com")!
    static let solanaIconURL = URL(
        string: "https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png"
    )!

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

    /// The public explorer page of `address` on an app-owned network, for history to fall back
    /// to when its indexer has nothing (Solana) or fails (Bitcoin). These networks have no
    /// registry explorers, and decisions.md lets history degrade to an explorer link, never to
    /// an error dead end. Solana opens Solscan, the explorer the browser extension links to.
    static func addressExplorerURL(for chainId: String, address: String) -> URL? {
        guard !address.isEmpty,
              address.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) && $0.isASCII }) else {
            return nil
        }

        switch chainId {
        case bitcoinMainnet.chainId, bitcoinMainnet.id:
            return URL(string: "https://mempool.space/address/\(address)")
        case bitcoinTestnet.chainId, bitcoinTestnet.id:
            return URL(string: "https://mempool.space/testnet/address/\(address)")
        case solanaMainnet.chainId, solanaMainnet.id:
            return URL(string: "https://solscan.io/account/\(address)")
        case solanaDevnet.chainId, solanaDevnet.id:
            return URL(string: "https://solscan.io/account/\(address)?cluster=devnet")
        default:
            return nil
        }
    }

    static func solanaNetwork(for chainId: String) -> SolanaNetwork? {
        switch chainId.lowercased() {
        case solanaMainnet.chainId, solanaMainnet.id:
            return solanaMainnet
        case solanaDevnet.chainId, solanaDevnet.id:
            return solanaDevnet
        default:
            return nil
        }
    }

    /// Bitcoin and Solana balances come from their own services, not from the Substrate
    /// account store, and neither network has an existential deposit.
    static func readsBalanceRemotely(_ chainId: String) -> Bool {
        bitcoinNetwork(for: chainId) != nil || solanaNetwork(for: chainId) != nil
    }

    static let solanaMainnet = SolanaNetwork(
        id: "solana-mainnet",
        genesisHash: "5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d",
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

    /// Solana is an app-owned network like Bitcoin: the shared registry does not publish a
    /// Solana row, so the wallet merges this one in at runtime. Its nodes are the JSON-RPC
    /// endpoints balances and sends use; nothing here talks to the testnet indexer.
    static let solanaMainnetChainModel: ChainModel = {
        let asset = AssetModel(
            id: solanaMainnet.nativeAsset.id,
            name: solanaMainnet.name,
            symbol: solanaMainnet.nativeAsset.symbol,
            precision: UInt16(solanaMainnet.nativeAsset.decimals),
            icon: solanaIconURL,
            currencyId: solanaMainnet.nativeAsset.id,
            color: "9945FF",
            isUtility: true,
            isNative: true,
            staking: nil,
            purchaseProviders: nil,
            type: nil,
            ethereumType: nil,
            priceProvider: PriceProvider(
                type: .coingecko,
                id: "solana",
                precision: nil
            ),
            coingeckoPriceId: "solana"
        )
        let nodes = solanaMainnetRPCURLs.map {
            ChainNodeModel(url: $0, name: $0.host ?? $0.absoluteString, apikey: nil)
        }

        return ChainModel(
            rank: 3,
            disabled: false,
            chainId: solanaMainnet.chainId,
            parentId: nil,
            paraId: nil,
            name: solanaMainnet.name,
            assets: [asset],
            xcm: nil,
            nodes: Set(nodes),
            addressPrefix: 0,
            types: nil,
            icon: solanaIconURL,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }()

    static let solanaDevnet = SolanaNetwork(
        id: "solana-devnet",
        genesisHash: "EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG",
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
        string: "https://raw.githubusercontent.com/soramitsu/fearless-iOS/master/remote-config/production/icons/chains/white/SORA.svg"
    )!
    static let tairaXorIconURL = URL(
        string: "https://raw.githubusercontent.com/soramitsu/fearless-iOS/master/remote-config/production/icons/tokens/coloured/XOR.svg"
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
        tairaChainModel,
        solanaMainnetChainModel
    ]

    static let nexus = IrohaNetwork(
        id: "sora-nexus-mainnet",
        chainId: "sora:nexus:global",
        chainDiscriminant: 753,
        toriiBaseURL: URL(string: "https://minamoto.sora.org")!,
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
        let enabledByDefault: Bool
        let features: [String]
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
        /// App-owned cluster identity; custom RPC endpoints must report this same genesis.
        let genesisHash: String
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
        let endpoints = network.toriiBaseURL.map { toriiBaseURL in
            [
                UniversalWalletRegistryEndpoint(
                    id: "\(network.id)-torii",
                    kind: .torii,
                    url: toriiBaseURL.absoluteString,
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
    /// Upgrade enrollment only fills absent networks. Existing dedicated keys,
    /// including keys imported from another phrase, retain their own identity.
    /// Explicit root recovery uses the stricter validation below before it may
    /// persist recovery material.
    ///
    /// `passphrase` is the wallet password. A missing network gets the account that password
    /// protects unless `enrollment` keeps the one the words alone open (see
    /// `UniversalWalletPasswordEnrollment`); an account already present is never replaced.
    static func addingMissingAppOwnedAccounts(
        to wallet: MetaAccountModel,
        mnemonic: String,
        passphrase: String = "",
        enrollment: UniversalWalletPasswordEnrollment = .unchecked
    ) throws -> MetaAccountModel {
        var accounts = wallet.chainAccounts
        let slots: [UniversalWalletSlot] = [.bitcoinMainnet, .bitcoinTestnet, .ton, .taira]
        for slot in slots {
            guard !accounts.contains(where: {
                UniversalWalletChainAccountSupport.chainId($0.chainId, matches: slot.chainId)
            }) else { continue }
            // A released native TON account has its own phrase and signing key.
            // Never shadow it with a BIP39-derived account during upgrade.
            if slot == .ton, wallet.legacyTonAccount != nil { continue }

            let publicKey = try slot.publicKey(for: UniversalWalletSecret(
                mnemonic: mnemonic,
                passphrase: enrollment.passphrase(for: slot, password: passphrase)
            ))
            accounts.insert(ChainAccountModel(
                chainId: slot.chainId,
                accountId: publicKey,
                publicKey: publicKey,
                cryptoType: slot.cryptoType.rawValue,
                ethereumBased: false
            ))
        }
        let updatedWallet = accounts == wallet.chainAccounts ? wallet : wallet.replacingChainAccounts(accounts)
        return try addingSolanaMainnetAccount(
            to: updatedWallet,
            mnemonic: mnemonic,
            passphrase: enrollment.passphrase(for: .solana, password: passphrase)
        )
    }

    /// The networks `addingMissingAppOwnedAccounts` would add to `wallet`.
    static func missingSlots(in wallet: MetaAccountModel) -> Set<UniversalWalletSlot> {
        Set(UniversalWalletSlot.allCases.filter { slot in
            switch slot {
            case .solana:
                return !wallet.chainAccounts.contains {
                    UniversalWalletChainAccountSupport.isValidSolanaAccount($0, chainId: slot.chainId)
                }
            case .ton where wallet.legacyTonAccount != nil:
                return false
            default:
                return !wallet.chainAccounts.contains {
                    UniversalWalletChainAccountSupport.chainId($0.chainId, matches: slot.chainId)
                }
            }
        })
    }

    static func addingAppOwnedAccounts(
        to wallet: MetaAccountModel,
        mnemonic: String,
        passphrase: String = "",
        enrollment: UniversalWalletPasswordEnrollment = .unchecked
    ) throws -> MetaAccountModel {
        let secret = UniversalWalletSecret(mnemonic: mnemonic, passphrase: passphrase)
        _ = try validateExistingAccount(
            in: wallet,
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            candidatePublicKeys: secret.candidates.map { try UniversalWalletSlot.bitcoinMainnet.publicKey(for: $0) },
            isStructurallyValid: {
                UniversalWalletChainAccountSupport.isValidBitcoinAccount($0)
            }
        )
        _ = try validateExistingAccount(
            in: wallet,
            chainId: UniversalWalletRegistry.taira.chainId,
            candidatePublicKeys: secret.candidates.map { try UniversalWalletSlot.taira.publicKey(for: $0) },
            isStructurallyValid: UniversalWalletChainAccountSupport.isValidTairaAccount
        )

        // Existing Bitcoin/Taira recovery validation remains strict. Other
        // dedicated accounts keep their independently imported identity.
        return try addingMissingAppOwnedAccounts(
            to: wallet,
            mnemonic: mnemonic,
            passphrase: passphrase,
            enrollment: enrollment
        )
    }

    /// An existing account must be one the phrase derives: with the wallet password, or
    /// without it as every earlier release did.
    private static func validateExistingAccount(
        in wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        candidatePublicKeys: [Data],
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
        guard isStructurallyValid(account), candidatePublicKeys.contains(account.publicKey) else {
            throw UniversalWalletRootRecoveryError.existingAccountUsesDifferentPhrase
        }

        return true
    }

    static func addingBitcoinMainnetAccount(
        to wallet: MetaAccountModel,
        mnemonic: String,
        passphrase: String = ""
    ) throws -> MetaAccountModel {
        let chainId = UniversalWalletRegistry.bitcoinMainnet.chainId
        let account = try BitcoinKeyDerivation.deriveAccount(
            mnemonic: mnemonic,
            passphrase: passphrase,
            network: .mainnet
        )
        if try validateExistingAccount(
            in: wallet,
            chainId: chainId,
            candidatePublicKeys: [account.publicKey],
            isStructurallyValid: { UniversalWalletChainAccountSupport.isValidBitcoinAccount($0) }
        ) {
            return wallet
        }
        let chainAccount = ChainAccountModel(
            chainId: chainId,
            accountId: account.publicKey,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ecdsa.rawValue,
            ethereumBased: false
        )

        var chainAccounts = wallet.chainAccounts
        chainAccounts.insert(chainAccount)

        guard chainAccounts != wallet.chainAccounts else {
            return wallet
        }

        return wallet.replacingChainAccounts(chainAccounts)
    }

    /// Adds the Solana account the phrase derives (m/44'/501'/0'/0', the address Phantom, the
    /// extension and Android show for the same phrase) when the wallet has no usable Solana
    /// account. An existing Solana account, including one imported from another phrase, is
    /// kept as it is: no Solana account was ever created by an earlier iOS release, so there
    /// is nothing to validate against, and replacing one could hide funds. A malformed row is
    /// kept too; the new account sits beside it. Only public keys are written.
    static func addingSolanaMainnetAccount(
        to wallet: MetaAccountModel,
        mnemonic: String,
        passphrase: String = ""
    ) throws -> MetaAccountModel {
        let chainId = UniversalWalletRegistry.solanaMainnet.chainId
        guard !wallet.chainAccounts.contains(where: {
            UniversalWalletChainAccountSupport.isValidSolanaAccount($0, chainId: chainId)
        }) else {
            return wallet
        }

        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic, passphrase: passphrase)
        let chainAccount = ChainAccountModel(
            chainId: chainId,
            accountId: account.publicKey,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue,
            ethereumBased: false
        )

        var chainAccounts = wallet.chainAccounts
        chainAccounts.insert(chainAccount)

        guard chainAccounts != wallet.chainAccounts else {
            return wallet
        }

        return wallet.replacingChainAccounts(chainAccounts)
    }

    static func addingTairaTestnetAccount(
        to wallet: MetaAccountModel,
        mnemonic: String,
        passphrase: String = ""
    ) throws -> MetaAccountModel {
        let chainId = UniversalWalletRegistry.taira.chainId
        let account = try IrohaKeyDerivation.deriveAccount(mnemonic: mnemonic, passphrase: passphrase)
        if try validateExistingAccount(
            in: wallet,
            chainId: chainId,
            candidatePublicKeys: [account.publicKey],
            isStructurallyValid: UniversalWalletChainAccountSupport.isValidTairaAccount
        ) {
            return wallet
        }
        let chainAccount = ChainAccountModel(
            chainId: chainId,
            accountId: account.publicKey,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue,
            ethereumBased: false
        )

        var chainAccounts = wallet.chainAccounts
        chainAccounts.insert(chainAccount)

        guard chainAccounts != wallet.chainAccounts else {
            return wallet
        }

        return wallet.replacingChainAccounts(chainAccounts)
    }
}
