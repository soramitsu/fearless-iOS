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

/// A funds check of one account.
struct UniversalWalletFundsReading: Equatable {
    let state: UniversalWalletFundsState
    /// The native balance in whole units with its symbol ("0.0001 BTC"), when it was read.
    var balance: String?
}

protocol UniversalWalletFundsProbing {
    /// The funds held by the accounts `secret` derives, per slot.
    func funds(
        of secret: UniversalWalletSecret,
        slots: Set<UniversalWalletSlot>
    ) async -> [UniversalWalletSlot: UniversalWalletFundsReading]
}

extension UniversalWalletFundsProbing {
    /// The funds held by the accounts `mnemonic` opens without a password, per slot.
    func noPasswordFunds(
        mnemonic: String,
        slots: Set<UniversalWalletSlot>
    ) async -> [UniversalWalletSlot: UniversalWalletFundsState] {
        await funds(of: UniversalWalletSecret(mnemonic: mnemonic, passphrase: ""), slots: slots).mapValues(\.state)
    }
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

    func funds(
        of secret: UniversalWalletSecret,
        slots: Set<UniversalWalletSlot>
    ) async -> [UniversalWalletSlot: UniversalWalletFundsReading] {
        await withTaskGroup(of: (UniversalWalletSlot, UniversalWalletFundsReading).self) { group in
            for slot in slots {
                group.addTask {
                    let timeout = slot == .bitcoinMainnet || slot == .bitcoinTestnet
                        ? Self.bitcoinTimeout
                        : Self.timeout
                    let reading = await Self.withTimeout(timeout) {
                        try await funds(of: slot, secret: secret)
                    }
                    return (slot, reading)
                }
            }
            var result: [UniversalWalletSlot: UniversalWalletFundsReading] = [:]
            for await checked in group {
                result[checked.0] = checked.1
            }
            return result
        }
    }

    private func funds(
        of slot: UniversalWalletSlot,
        secret: UniversalWalletSecret
    ) async throws -> UniversalWalletFundsReading {
        switch slot {
        case .bitcoinMainnet:
            return try await bitcoinFunds(secret: secret, network: .mainnet, indexerNetwork: .mainnet)
        case .bitcoinTestnet:
            return try await bitcoinFunds(secret: secret, network: .testnet, indexerNetwork: .testnet)
        case .solana:
            return try await solanaFunds(secret: secret)
        case .taira:
            return try await UniversalWalletFundsReading(state: tairaFunds(secret: secret))
        case .ton:
            return try await UniversalWalletFundsReading(state: tonFunds(secret: secret))
        }
    }

    /// Every address of the account, both branches to the gap limit, confirmed or not.
    private func bitcoinFunds(
        secret: UniversalWalletSecret,
        network: BitcoinKeyDerivation.Network,
        indexerNetwork: BitcoinIndexerNetwork
    ) async throws -> UniversalWalletFundsReading {
        let result = try await bitcoinBalanceSync.balance(
            mnemonic: secret.mnemonic,
            passphrase: secret.passphrase,
            network: network,
            baseURL: indexerNetwork.defaultBaseURL.absoluteString,
            gapLimit: nil,
            maxLookahead: BitcoinReceiveDiscovery.defaultMaxLookahead
        )
        let symbol = network == .mainnet ? "BTC" : "tBTC"
        return UniversalWalletFundsReading(
            state: result.totalSats > 0 ? .funded : .empty,
            balance: Self.wholeUnits(Decimal(result.totalSats), decimals: 8, symbol: symbol)
        )
    }

    /// SOL and SPL tokens; token accounts no node returned leave an empty read unknown.
    private func solanaFunds(secret: UniversalWalletSecret) async throws -> UniversalWalletFundsReading {
        guard let solanaBalanceSync else {
            return UniversalWalletFundsReading(state: .unknown)
        }
        let address = try SolanaKeyDerivation.deriveAccount(
            mnemonic: secret.mnemonic, passphrase: secret.passphrase
        ).address
        let result = try await solanaBalanceSync.portfolioBalances(
            wallet: address,
            network: UniversalWalletRegistry.solanaMainnet
        )
        let lamports = Decimal(string: result.nativeBalance.amount) ?? .zero
        let balance = Self.wholeUnits(lamports, decimals: 9, symbol: "SOL")
        let amounts = ([result.nativeBalance] + result.tokenBalances).map(\.amount)
        if amounts.contains(where: { (Decimal(string: $0) ?? .zero) > .zero }) {
            return UniversalWalletFundsReading(state: .funded, balance: balance)
        }
        return UniversalWalletFundsReading(state: result.tokenBalancesUnavailable ? .unknown : .empty, balance: balance)
    }

    private static func wholeUnits(_ amount: Decimal, decimals: Int, symbol: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = decimals
        var units = amount
        var divisor = Decimal(1)
        for _ in 0 ..< decimals {
            divisor *= 10
        }
        units /= divisor
        let text = formatter.string(from: units as NSDecimalNumber) ?? "\(units)"
        return "\(text) \(symbol)"
    }

    private func tairaFunds(secret: UniversalWalletSecret) async throws -> UniversalWalletFundsState {
        let address = try IrohaKeyDerivation.deriveAddress(
            mnemonic: secret.mnemonic, passphrase: secret.passphrase
        ).i105
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
    private func tonFunds(secret: UniversalWalletSecret) async throws -> UniversalWalletFundsState {
        // The catalog stores TON under its workchain id.
        guard let tonBalanceFetching,
              let chain = chainProvider(TonChainSelection.mainnetChainId)
              ?? chainProvider(UniversalWalletSlot.ton.chainId)
        else {
            return .unknown
        }
        let publicKey = try TonKeyDerivation.deriveAccount(
            mnemonic: secret.mnemonic, passphrase: secret.passphrase
        ).publicKey
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
        _ body: @escaping () async throws -> UniversalWalletFundsReading
    ) async -> UniversalWalletFundsReading {
        await withTaskGroup(of: UniversalWalletFundsReading?.self) { group in
            group.addTask { (try? await body()) ?? UniversalWalletFundsReading(state: .unknown) }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? UniversalWalletFundsReading(state: .unknown)
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
