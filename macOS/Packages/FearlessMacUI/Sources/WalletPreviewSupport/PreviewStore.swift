import Foundation
import WalletCore

/// All mutable state of the in-memory services. One actor, so the fake
/// vault, wallets, balances and history stay consistent with each other.
actor PreviewStore {
    let scenario: PreviewScenario

    private(set) var vaultState: VaultState
    private var password: String?
    private var biometricsEnabled: Bool
    private var observers: [UUID: AsyncStream<VaultState>.Continuation] = [:]

    private(set) var wallets: [StoredWallet]
    private var balances: [WalletID: [AssetID: PreviewBalance]]
    private var activity: [ActivityItem]
    private var customNodes: [ChainID: [ChainNode]] = [:]
    private var selectedNodes: [ChainID: ChainNode] = [:]
    private var transferCounter = 1_000

    init(scenario: PreviewScenario) {
        self.scenario = scenario
        let now = Date()
        switch scenario.vault {
        case .uninitialized:
            vaultState = .uninitialized
            password = nil
        case .locked:
            vaultState = .locked
            password = scenario.password
        case .unlocked:
            vaultState = .unlocked
            password = scenario.password
        }
        if case .enabled = scenario.biometrics { biometricsEnabled = true } else { biometricsEnabled = false }
        switch scenario.wallets {
        case .none:
            wallets = []
            balances = [:]
            activity = []
        case .standard:
            wallets = scenario.vault == .uninitialized ? [] : PreviewSampleData.standardWallets(now: now)
            balances = scenario.vault == .uninitialized ? [:] : PreviewSampleData.standardBalances()
            activity = scenario.vault == .uninitialized ? [] : PreviewSampleData.standardActivity(now: now)
        }
    }

    /// Simulated network or disk delay.
    func pause(scale: Double = 1) async {
        let range = scenario.latency.seconds
        guard range.upperBound > 0 else { return }
        try? await Task.sleep(for: .seconds(Double.random(in: range) * scale))
    }

    // MARK: Vault

    func addObserver(_ id: UUID, _ continuation: AsyncStream<VaultState>.Continuation) {
        observers[id] = continuation
        continuation.yield(vaultState)
    }

    func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    private func setVaultState(_ state: VaultState) {
        vaultState = state
        for continuation in observers.values { continuation.yield(state) }
    }

    func initialize(password newPassword: String) throws {
        guard PasswordPolicy.isAcceptable(newPassword) else { throw WalletError.passwordTooWeak }
        password = newPassword
        setVaultState(.unlocked)
    }

    func check(_ approval: UserApproval) throws {
        guard let password else { throw WalletError.vaultNotInitialized }
        switch approval {
        case .password(let candidate):
            guard candidate == password else { throw WalletError.wrongPassword }
        case .biometrics:
            guard biometricsEnabled else { throw WalletError.biometricsUnavailable }
        }
    }

    func unlock(_ approval: UserApproval) throws {
        try check(approval)
        setVaultState(.unlocked)
    }

    func lock() {
        guard vaultState == .unlocked else { return }
        setVaultState(.locked)
    }

    func changePassword(current: String, new: String) throws {
        try check(.password(current))
        guard PasswordPolicy.isAcceptable(new) else { throw WalletError.passwordTooWeak }
        password = new
    }

    func biometricsAvailability() -> BiometricsAvailability {
        if case .unavailable = scenario.biometrics { return scenario.biometrics }
        return biometricsEnabled ? .enabled : .available
    }

    func setBiometricsEnabled(_ enabled: Bool, password candidate: String) throws {
        if case .unavailable = scenario.biometrics { throw WalletError.biometricsUnavailable }
        try check(.password(candidate))
        biometricsEnabled = enabled
    }

    func eraseAll() {
        wallets = []
        balances = [:]
        activity = []
        customNodes = [:]
        selectedNodes = [:]
        password = nil
        biometricsEnabled = false
        setVaultState(.uninitialized)
    }

    // MARK: Wallets

    func requireUnlocked() throws {
        switch vaultState {
        case .uninitialized: throw WalletError.vaultNotInitialized
        case .locked: throw WalletError.vaultLocked
        case .unlocked: return
        }
    }

    func stored(_ id: WalletID) throws -> StoredWallet {
        guard let wallet = wallets.first(where: { $0.wallet.id == id }) else { throw WalletError.walletNotFound }
        return wallet
    }

    func add(_ candidate: StoredWallet) throws -> Wallet {
        if let existing = wallets.first(where: { existing in
            (candidate.substrateAccount != nil && existing.substrateAccount == candidate.substrateAccount)
                || (candidate.evmAddress != nil && existing.evmAddress?.lowercased() == candidate.evmAddress?.lowercased())
        }) {
            throw WalletError.duplicateWallet(existing: existing.wallet.id)
        }
        wallets.append(candidate)
        // A wallet added in the demo starts with a little of everything so the screens are not empty.
        var starter: [AssetID: PreviewBalance] = [:]
        for asset in PreviewCatalog.assets {
            let text = asset.id == PreviewCatalog.dot.id ? "12.5" : (asset.id == PreviewCatalog.eth.id ? "0.05" : "0")
            starter[asset.id] = PreviewBalance(total: PreviewCatalog.amount(text, asset.decimals), locked: .zero(decimals: asset.decimals))
        }
        balances[candidate.wallet.id] = starter
        return candidate.wallet
    }

    func rename(_ id: WalletID, to name: String) throws {
        guard let index = wallets.firstIndex(where: { $0.wallet.id == id }) else { throw WalletError.walletNotFound }
        wallets[index].wallet.name = name
    }

    func delete(_ id: WalletID) throws {
        guard wallets.contains(where: { $0.wallet.id == id }) else { throw WalletError.walletNotFound }
        wallets.removeAll { $0.wallet.id == id }
        balances[id] = nil
        activity.removeAll { $0.walletID == id }
    }

    func markBackedUp(_ id: WalletID) throws {
        guard let index = wallets.firstIndex(where: { $0.wallet.id == id }) else { throw WalletError.walletNotFound }
        wallets[index].wallet.isBackedUp = true
    }

    // MARK: Balances and history

    func balance(of walletID: WalletID, asset: AssetID) -> Result<AssetBalance, WalletError> {
        guard let wallet = wallets.first(where: { $0.wallet.id == walletID }) else { return .failure(.walletNotFound) }
        guard let chain = PreviewCatalog.chain(asset.chainID), let model = PreviewCatalog.asset(asset) else {
            return .failure(.unsupportedAsset)
        }
        guard wallet.address(on: chain) != nil else { return .failure(.unsupportedChain) }
        if scenario.failingChains.contains(chain.id) {
            return .failure(.network("\(chain.name) did not answer. Check the node in Settings."))
        }
        let held = balances[walletID]?[asset] ?? PreviewBalance(total: .zero(decimals: model.decimals), locked: .zero(decimals: model.decimals))
        return .success(AssetBalance(assetID: asset, total: held.total, transferable: held.transferable, locked: held.locked))
    }

    func held(_ walletID: WalletID, _ asset: AssetID) -> PreviewBalance? {
        balances[walletID]?[asset]
    }

    func history(of walletID: WalletID, assets: [AssetID]?) -> ActivityPage {
        let unavailable = Dictionary(uniqueKeysWithValues: scenario.historyUnavailableChains.map { chainID in
            (chainID, "\(PreviewCatalog.chain(chainID)?.name ?? "This network")'s history service did not answer.")
        })
        let items = activity
            .filter { $0.walletID == walletID }
            .filter { assets?.contains($0.assetID) ?? true }
            .filter { !scenario.historyUnavailableChains.contains($0.assetID.chainID) }
            .sorted { $0.timestamp > $1.timestamp }
        return ActivityPage(items: items, unavailable: unavailable)
    }

    /// Records a submitted transfer as pending and returns its made-up hash.
    func beginTransfer(_ request: TransferRequest, fee: FeeEstimate?) -> (id: String, hash: String) {
        transferCounter += 1
        let hash = PreviewSampleData.fakeHash(transferCounter)
        let id = "preview-transfer-\(transferCounter)"
        let chain = PreviewCatalog.chain(request.assetID.chainID)
        activity.append(ActivityItem(
            id: id, walletID: request.walletID, assetID: request.assetID, direction: .outgoing,
            counterparty: request.recipient, amount: request.amount, fee: fee?.amount, timestamp: Date(), status: .pending,
            hash: hash, explorerURL: chain?.explorer?.transactionURL(hash: hash)
        ))
        return (id, hash)
    }

    /// Settles a pending transfer; a successful one leaves the sender's balance.
    func finishTransfer(id: String, request: TransferRequest, fee: FeeEstimate?, success: Bool) {
        if let index = activity.firstIndex(where: { $0.id == id }) {
            activity[index].status = success ? .success : .failed
        }
        guard success else { return }
        if var held = balances[request.walletID]?[request.assetID] {
            held.total = held.total.subtractingClamped(request.amount)
            balances[request.walletID]?[request.assetID] = held
        }
        if let fee, var held = balances[request.walletID]?[fee.assetID] {
            held.total = held.total.subtractingClamped(fee.amount)
            balances[request.walletID]?[fee.assetID] = held
        }
    }

    // MARK: Nodes

    func nodes(for chainID: ChainID) -> [ChainNode] {
        PreviewCatalog.defaultNodes(for: chainID) + (customNodes[chainID] ?? [])
    }

    func selectedNode(for chainID: ChainID) -> ChainNode? {
        selectedNodes[chainID]
    }

    func selectNode(_ node: ChainNode?, for chainID: ChainID) {
        selectedNodes[chainID] = node
    }

    func addCustomNode(name: String, url: URL, for chainID: ChainID) throws -> ChainNode {
        guard let chain = PreviewCatalog.chain(chainID) else { throw WalletError.unsupportedChain }
        let scheme = url.scheme?.lowercased() ?? ""
        let allowed: Set<String> = chain.ecosystem == .substrate ? ["wss", "ws"] : ["https", "http", "wss", "ws"]
        guard allowed.contains(scheme), url.host != nil else {
            let schemes = allowed.sorted().map { $0 + "://" }.joined(separator: " or ")
            throw WalletError.network("The address must start with " + schemes + ".")
        }
        if nodes(for: chainID).contains(where: { $0.url == url }) {
            throw WalletError.network("This node is already in the list.")
        }
        if url.absoluteString.contains("unreachable") {
            throw WalletError.network("The node did not answer.")
        }
        let node = ChainNode(name: name.isEmpty ? (url.host ?? "Custom node") : name, url: url, isCustom: true)
        customNodes[chainID, default: []].append(node)
        return node
    }

    func removeCustomNode(_ node: ChainNode, for chainID: ChainID) {
        customNodes[chainID]?.removeAll { $0.id == node.id }
        if selectedNodes[chainID]?.id == node.id { selectedNodes[chainID] = nil }
    }
}
