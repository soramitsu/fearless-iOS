import Foundation
import RobinHood
import SSFModels

/// What a funds check found at an address.
enum UniversalWalletFundsState: Equatable {
    case funded
    case empty
    /// Offline, failed, timed out or not checkable: treated as funds that must stay visible.
    case unknown
}

protocol UniversalWalletFundsProbing {
    /// The funds held by the accounts `mnemonic` opens without a password, per slot.
    func noPasswordFunds(
        mnemonic: String,
        slots: Set<UniversalWalletSlot>
    ) async -> [UniversalWalletSlot: UniversalWalletFundsState]
}

/// Reads balances with the clients the portfolio uses. Every failure, timeout or partial
/// read is `unknown`, which keeps the account visible.
struct UniversalWalletRemoteFundsProbe: UniversalWalletFundsProbing {
    static let timeout: TimeInterval = 6
    /// A Bitcoin wallet scan walks both address branches to the gap limit.
    static let bitcoinTimeout: TimeInterval = 30

    private let bitcoinBalanceSync: BitcoinBalanceSyncing
    private let solanaBalanceSync: SolanaBalanceSyncing?
    private let irohaToriiClient: IrohaToriiClientProtocol
    private let tonBalanceFetching: AccountInfoRemoteService?
    private let chainProvider: (ChainModel.Id) -> ChainModel?

    init(
        bitcoinBalanceSync: BitcoinBalanceSyncing = BitcoinBalanceSync(
            discovery: BitcoinReceiveDiscovery(client: BitcoinFailoverIndexerClient())
        ),
        solanaBalanceSync: SolanaBalanceSyncing? = SolanaRpcBalanceSync.mainnet,
        irohaToriiClient: IrohaToriiClientProtocol = IrohaToriiClient(),
        tonBalanceFetching: AccountInfoRemoteService?,
        chainProvider: @escaping (ChainModel.Id) -> ChainModel?
    ) {
        self.bitcoinBalanceSync = bitcoinBalanceSync
        self.solanaBalanceSync = solanaBalanceSync
        self.irohaToriiClient = irohaToriiClient
        self.tonBalanceFetching = tonBalanceFetching
        self.chainProvider = chainProvider
    }

    func noPasswordFunds(
        mnemonic: String,
        slots: Set<UniversalWalletSlot>
    ) async -> [UniversalWalletSlot: UniversalWalletFundsState] {
        await withTaskGroup(of: (UniversalWalletSlot, UniversalWalletFundsState).self) { group in
            for slot in slots {
                group.addTask {
                    let timeout = slot == .bitcoinMainnet || slot == .bitcoinTestnet
                        ? Self.bitcoinTimeout
                        : Self.timeout
                    let state = await Self.withTimeout(timeout) {
                        try await funds(of: slot, mnemonic: mnemonic)
                    }
                    return (slot, state)
                }
            }
            var result: [UniversalWalletSlot: UniversalWalletFundsState] = [:]
            for await checked in group {
                result[checked.0] = checked.1
            }
            return result
        }
    }

    private func funds(of slot: UniversalWalletSlot, mnemonic: String) async throws -> UniversalWalletFundsState {
        switch slot {
        case .bitcoinMainnet:
            return try await bitcoinFunds(mnemonic: mnemonic, network: .mainnet, indexerNetwork: .mainnet)
        case .bitcoinTestnet:
            return try await bitcoinFunds(mnemonic: mnemonic, network: .testnet, indexerNetwork: .testnet)
        case .solana:
            return try await solanaFunds(mnemonic: mnemonic)
        case .taira:
            return try await tairaFunds(mnemonic: mnemonic)
        case .ton:
            return try await tonFunds(mnemonic: mnemonic)
        }
    }

    /// Every address of the account, both branches to the gap limit, confirmed or not.
    private func bitcoinFunds(
        mnemonic: String,
        network: BitcoinKeyDerivation.Network,
        indexerNetwork: BitcoinIndexerNetwork
    ) async throws -> UniversalWalletFundsState {
        let result = try await bitcoinBalanceSync.balance(
            mnemonic: mnemonic,
            passphrase: "",
            network: network,
            baseURL: indexerNetwork.defaultBaseURL.absoluteString,
            gapLimit: nil,
            maxLookahead: BitcoinReceiveDiscovery.defaultMaxLookahead
        )
        return result.totalSats > 0 ? .funded : .empty
    }

    /// SOL and SPL tokens; token accounts no node returned leave an empty read unknown.
    private func solanaFunds(mnemonic: String) async throws -> UniversalWalletFundsState {
        guard let solanaBalanceSync else {
            return .unknown
        }
        let address = try SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic).address
        let result = try await solanaBalanceSync.portfolioBalances(
            wallet: address,
            network: UniversalWalletRegistry.solanaMainnet
        )
        let amounts = ([result.nativeBalance] + result.tokenBalances).map(\.amount)
        if amounts.contains(where: { (Decimal(string: $0) ?? .zero) > .zero }) {
            return .funded
        }
        return result.tokenBalancesUnavailable ? .unknown : .empty
    }

    private func tairaFunds(mnemonic: String) async throws -> UniversalWalletFundsState {
        let address = try IrohaKeyDerivation.deriveAddress(mnemonic: mnemonic).i105
        let response = try await irohaToriiClient.accountAssets(
            accountID: address,
            baseURL: nil,
            limit: IrohaToriiRoutes.maxLimit,
            cursor: nil,
            network: UniversalWalletRegistry.taira
        )
        if response.items.contains(where: { (Decimal(string: $0.quantity) ?? .zero) > .zero }) {
            return .funded
        }
        return response.nextCursor == nil ? .empty : .unknown
    }

    /// TON and Jettons, read like the portfolio reads them.
    private func tonFunds(mnemonic: String) async throws -> UniversalWalletFundsState {
        // The catalog stores TON under its workchain id.
        guard let tonBalanceFetching,
              let chain = chainProvider(TonChainSelection.mainnetChainId)
              ?? chainProvider(UniversalWalletSlot.ton.chainId)
        else {
            return .unknown
        }
        let publicKey = try TonKeyDerivation.deriveAccount(mnemonic: mnemonic).publicKey
        let infos = try await tonBalanceFetching.fetchAccountInfos(
            for: chain,
            wallet: Self.probeWallet(chainId: chain.chainId, publicKey: publicKey)
        )
        return infos.values.contains { ($0?.data.total ?? .zero) > .zero } ? .funded : .empty
    }

    /// A wallet holding only the account to read; it is never saved.
    private static func probeWallet(chainId: ChainModel.Id, publicKey: Data) -> MetaAccountModel {
        MetaAccountModel(
            metaId: "universal-wallet-funds-probe",
            name: "",
            substrateAccountId: nil,
            substrateCryptoType: CryptoType.sr25519.rawValue,
            substratePublicKey: nil,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [ChainAccountModel(
                chainId: chainId,
                accountId: publicKey,
                publicKey: publicKey,
                cryptoType: CryptoType.ed25519.rawValue,
                ethereumBased: false
            )],
            assetKeysOrder: nil,
            canExportEthereumMnemonic: false,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: false,
            favouriteChainIds: []
        )
    }

    private static func withTimeout(
        _ seconds: TimeInterval,
        _ body: @escaping () async throws -> UniversalWalletFundsState
    ) async -> UniversalWalletFundsState {
        await withTaskGroup(of: UniversalWalletFundsState?.self) { group in
            group.addTask { (try? await body()) ?? .unknown }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? .unknown
        }
    }
}

extension UniversalWalletRemoteFundsProbe {
    /// The portfolio's own readers, including its TON balance and Jetton reader.
    static func makeDefault() -> UniversalWalletRemoteFundsProbe {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let logger = Logger.shared
        let repository = SubstrateRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
            .createAccountInfoStorageItemRepository()
        let chainRepository = ChainRepositoryFactory().createAsyncRepository()
        let tonBalanceFetching = TonRemoteBalanceFetchingImpl(
            chainRegistry: chainRegistry,
            repositoryWrapper: BalanceRepositoryCacheWrapper(
                logger: logger,
                repository: repository,
                operationManager: OperationManagerFacade.sharedManager
            ),
            jettonInjector: TonJettonInjectorImpl(
                chainModelRepository: AsyncAnyRepository(chainRepository),
                eventCenter: EventCenter.shared,
                logger: logger
            )
        )
        return UniversalWalletRemoteFundsProbe(
            tonBalanceFetching: tonBalanceFetching,
            chainProvider: { chainRegistry.getChain(for: $0) }
        )
    }
}
