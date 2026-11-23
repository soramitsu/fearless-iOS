import Foundation

// The UI talks to the wallet only through these protocols. The engine
// (FearlessMacEngine/WalletEngine) implements them for real networks; the UI
// package ships an in-memory implementation for previews, demos and tests.
// Every method is safe to call from the main actor; implementations do their
// own work off the main thread.

/// App password, lock state and Touch ID. Secrets are only readable while
/// the vault is unlocked.
public protocol VaultServicing: Sendable {
    func state() async -> VaultState
    /// Emits the current state first, then every change (lock, unlock, erase).
    func stateUpdates() -> AsyncStream<VaultState>
    /// First run: sets the app password and leaves the vault unlocked.
    /// Throws `.passwordTooWeak` when `PasswordPolicy.isAcceptable` is false.
    func initialize(password: String) async throws
    func unlock(_ approval: UserApproval) async throws
    func lock() async
    func changePassword(current: String, new: String) async throws
    func biometricsAvailability() async -> BiometricsAvailability
    func setBiometricsEnabled(_ enabled: Bool, password: String) async throws
    /// Re-checks the user without changing lock state (before revealing a
    /// phrase, exporting or signing). Throws `.wrongPassword` /
    /// `.biometricsCancelled`.
    func verify(_ approval: UserApproval) async throws
    /// Deletes every wallet, secret and setting of the engine ("Forgot
    /// password"). Leaves the vault `.uninitialized`.
    func eraseAllData() async throws
}

public protocol WalletServicing: Sendable {
    func wallets() async throws -> [Wallet]
    /// BIP-39 English word list, for autocomplete in phrase entry.
    var mnemonicWordList: [String] { get }
    func generateMnemonic(length: MnemonicLength) async throws -> [String]
    func validateMnemonic(_ words: [String]) async -> MnemonicValidation
    /// Addresses an import would produce; does not store anything.
    func previewAddresses(for source: WalletImportSource) async throws -> WalletAddressPreview
    /// Stores a new wallet. Needs an unlocked vault (except watch-only).
    /// Throws `.duplicateWallet` if the same accounts already exist.
    /// `.created` wallets start with `isBackedUp == false`; every other
    /// source is stored as backed up (the user already holds the backup).
    func addWallet(name: String, source: WalletImportSource) async throws -> Wallet
    func renameWallet(_ id: WalletID, to name: String) async throws
    func deleteWallet(_ id: WalletID) async throws
    func markBackedUp(_ id: WalletID) async throws
    /// Re-verifies the user, then returns the phrase with its derivation options.
    func exportMnemonic(_ id: WalletID, approval: UserApproval) async throws -> MnemonicBackup
    /// Polkadot.js-compatible JSON keystore of the wallet's account for `ecosystem`.
    func exportJSON(_ id: WalletID, ecosystem: Ecosystem, approval: UserApproval, exportPassword: String) async throws -> Data
    /// The wallet's address on `chainID`, formatted for that chain.
    func address(of id: WalletID, on chainID: ChainID) async throws -> String
}

public protocol ChainCatalogServicing: Sendable {
    func chains() async -> [Chain]
    func assets() async -> [Asset]
}

public protocol NodeServicing: Sendable {
    func nodes(for chainID: ChainID) async -> [ChainNode]
    /// The node in use; nil means automatic selection.
    func selectedNode(for chainID: ChainID) async -> ChainNode?
    func selectNode(_ node: ChainNode?, for chainID: ChainID) async
    /// Checks the endpoint answers for the right network before saving it.
    func addCustomNode(name: String, url: URL, for chainID: ChainID) async throws -> ChainNode
    func removeCustomNode(_ node: ChainNode, for chainID: ChainID) async
}

public protocol BalanceServicing: Sendable {
    /// Fetches balances; one result per requested asset. A failing chain
    /// never hides the others.
    func balances(of walletID: WalletID, assets: [AssetID]) async -> [AssetID: Result<AssetBalance, WalletError>]
}

public protocol PriceServicing: Sendable {
    func prices(for priceIDs: Set<String>, in currency: FiatCurrency) async throws -> [String: AssetPrice]
}

public protocol TransferServicing: Sendable {
    func validateRecipient(_ address: String, on chainID: ChainID) async -> RecipientValidation
    /// Fee, max sendable and every issue for a draft. Never throws; network
    /// problems become `.network` issues. `fee` and `maxSendable` are
    /// estimated (against the wallet's own address) also when the recipient
    /// is empty or invalid or the amount is zero, so "Max" works on a
    /// half-filled form; the issues still report what is missing.
    func prepare(_ request: TransferRequest) async -> TransferPreparation
    /// Re-verifies the user, signs and submits; the stream reports each stage
    /// and ends after `.finalized`, `.failed` or `.outcomeUnknown`. Throws before signing on a
    /// failed approval or a blocking issue.
    func submit(_ request: TransferRequest, approval: UserApproval) async throws -> AsyncThrowingStream<TransferProgress, Error>
}

public protocol ActivityServicing: Sendable {
    /// History of the wallet, newest first, optionally limited to some assets.
    /// Not paged yet: the engine returns at most a recent window per chain.
    func activity(of walletID: WalletID, assets: [AssetID]?) async throws -> ActivityPage
}

/// Everything the UI needs, injected at the app's composition root.
public struct WalletServices: Sendable {
    public let vault: any VaultServicing
    public let wallets: any WalletServicing
    public let catalog: any ChainCatalogServicing
    public let nodes: any NodeServicing
    public let balances: any BalanceServicing
    public let prices: any PriceServicing
    public let transfers: any TransferServicing
    public let activity: any ActivityServicing

    public init(
        vault: any VaultServicing,
        wallets: any WalletServicing,
        catalog: any ChainCatalogServicing,
        nodes: any NodeServicing,
        balances: any BalanceServicing,
        prices: any PriceServicing,
        transfers: any TransferServicing,
        activity: any ActivityServicing
    ) {
        self.vault = vault
        self.wallets = wallets
        self.catalog = catalog
        self.nodes = nodes
        self.balances = balances
        self.prices = prices
        self.transfers = transfers
        self.activity = activity
    }
}
