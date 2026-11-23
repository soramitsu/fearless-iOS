import AppKit
import DesignSystem
import Foundation
import Observation
import WalletCore

/// The app's state: vault phase, wallets, the selected wallet's data,
/// navigation and sheets. Views read it; commands call it.
@MainActor
@Observable
public final class AppModel {
    public let services: WalletServices
    public let settings: AppSettings

    let portfolio: PortfolioStore
    let activity: ActivityStore
    let securitySettings: SecuritySettingsModel
    let walletsSettings: WalletsSettingsModel
    let networkNodes: NodesModel
    let settingsNodes: NodesModel

    private(set) var vaultState: VaultState?
    private(set) var wallets: [Wallet] = []
    private(set) var walletsLoaded = false
    private(set) var walletsError: String?
    private(set) var selectedWalletID: WalletID?
    private(set) var onboarding: OnboardingModel?
    private(set) var lockModel: LockModel
    private(set) var toast: Toast?

    var section: SidebarSection = .portfolio
    var searchText = ""
    var sheet: SheetRoute?
    var selectedAssetID: AssetID?
    var selectedActivityID: String?
    var selectedNetworkID: ChainID?

    @ObservationIgnored private var autoLock: AutoLockController?
    @ObservationIgnored private var stateTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var started = false

    @ObservationIgnored private let clipboard: Clipboard

    /// - Parameter clipboard: where "Copy Address" writes; the general
    ///   pasteboard unless a test supplies its own.
    public init(services: WalletServices, settings: AppSettings? = nil, clipboard: Clipboard? = nil) {
        let settings = settings ?? AppSettings()
        self.services = services
        self.settings = settings
        self.clipboard = clipboard ?? .shared
        portfolio = PortfolioStore(services: services)
        activity = ActivityStore(services: services)
        securitySettings = SecuritySettingsModel(vault: services.vault)
        lockModel = LockModel(vault: services.vault)
        networkNodes = NodesModel(nodeService: services.nodes)
        settingsNodes = NodesModel(nodeService: services.nodes)
        // The wallets model reports changes back so lists stay current.
        let relay = ChangeRelay()
        walletsSettings = WalletsSettingsModel(services: services) { await relay.fire() }
        relay.action = { [weak self] in await self?.walletsChanged() }
    }

    // MARK: Lifecycle

    /// Starts following the vault and (optionally) the system events that
    /// lock the app. Safe to call more than once.
    public func start(monitorSystem: Bool = true) {
        guard !started else { return }
        started = true
        BrandFont.registerIfNeeded()
        applyAppearance()
        if monitorSystem {
            let controller = AutoLockController(
                policy: { [weak self] in
                    self?.settings.autoLockPolicy ?? AutoLockPolicy(idleMinutes: 5, lockOnSleep: true, lockOnScreenLock: true)
                },
                isUnlocked: { [weak self] in self?.vaultState == .unlocked },
                lock: { [weak self] in self?.lock() }
            )
            controller.start()
            autoLock = controller
        }
        let vault = services.vault
        stateTask = Task { [weak self] in
            for await state in vault.stateUpdates() {
                guard let self else { return }
                await self.handle(state)
            }
        }
    }

    var route: RootRoute {
        guard let vaultState else { return .launching }
        switch vaultState {
        case .uninitialized: return .onboarding
        case .locked: return .locked
        case .unlocked: return onboarding != nil ? .onboarding : .main
        }
    }

    var isUnlocked: Bool { vaultState == .unlocked }

    /// Reacts to a vault state change. Locking and erasing drop everything
    /// sensitive the interface holds.
    func handle(_ state: VaultState) async {
        let previous = vaultState
        vaultState = state
        switch state {
        case .uninitialized:
            clearSensitiveState()
            // Nothing to forget at a first launch; after "Erase All Data" this
            // drops the hidden assets and the remembered wallet.
            settings.forgetWalletState()
            onboarding = makeOnboarding(.firstRun)
        case .locked:
            clearSensitiveState()
            onboarding = nil
            lockModel = LockModel(vault: services.vault)
            await lockModel.load()
        case .unlocked:
            guard previous != .unlocked else { return }
            autoLock?.noteActivity()
            if let onboarding, onboarding.mode == .firstRun {
                // The password was just set; the flow goes on to the first wallet.
                return
            }
            await loadWallets()
            if walletsLoaded, wallets.isEmpty {
                onboarding = makeOnboarding(.firstWallet)
            }
            await refresh()
        }
    }

    private func makeOnboarding(_ mode: OnboardingModel.Mode) -> OnboardingModel {
        OnboardingModel(mode: mode, services: services, existingWalletCount: wallets.count) { [weak self] wallet in
            self?.finishOnboarding(with: wallet)
        }
    }

    private func finishOnboarding(with wallet: Wallet) {
        onboarding = nil
        if case .addWallet = sheet { sheet = nil }
        Task {
            await loadWallets()
            await selectWallet(wallet.id)
        }
    }

    /// Forgets wallet data, typed secrets and open sheets.
    private func clearSensitiveState() {
        // Every lock path, including ones the vault starts: a copied phrase goes too.
        clipboard.clearConcealed()
        if case .send(let model) = sheet { model.cancelObservation() }
        if case .addWallet(let model) = sheet { model.wipeSecrets() }
        onboarding?.wipeSecrets()
        sheet = nil
        portfolio.reset()
        activity.reset()
        walletsSettings.reset()
        securitySettings.clearSecrets()
        wallets = []
        walletsLoaded = false
        walletsError = nil
        selectedWalletID = nil
        selectedAssetID = nil
        selectedActivityID = nil
        searchText = ""
        toast = nil
    }

    // MARK: Wallets

    var selectedWallet: Wallet? {
        wallets.first { $0.id == selectedWalletID }
    }

    func loadWallets() async {
        do {
            let loaded = try await services.wallets.wallets()
            wallets = loaded
            walletsLoaded = true
            walletsError = nil
            if selectedWallet == nil {
                let remembered = loaded.first { $0.id.description == settings.selectedWalletID }
                selectedWalletID = (remembered ?? loaded.first)?.id
            }
        } catch {
            walletsError = ErrorText.message(for: error)
        }
    }

    func selectWallet(_ id: WalletID) async {
        guard wallets.contains(where: { $0.id == id }) else { return }
        if id != selectedWalletID {
            selectedWalletID = id
            selectedAssetID = nil
            selectedActivityID = nil
            portfolio.reset()
            activity.reset()
        }
        settings.selectedWalletID = id.description
        await refresh()
    }

    /// Selects the wallet at a one-based position (⌘1…⌘9).
    func selectWallet(at position: Int) async {
        guard wallets.indices.contains(position - 1) else { return }
        await selectWallet(wallets[position - 1].id)
    }

    /// Wallets were renamed, deleted or backed up in Settings.
    private func walletsChanged() async {
        let before = selectedWalletID
        await loadWallets()
        if selectedWallet == nil {
            selectedWalletID = wallets.first?.id
        }
        if wallets.isEmpty, walletsLoaded, isUnlocked {
            portfolio.reset()
            activity.reset()
            onboarding = makeOnboarding(.firstWallet)
        } else if before != selectedWalletID {
            portfolio.reset()
            activity.reset()
            await refresh()
        }
    }

    /// True when the wallet's phrase has not been confirmed as written down.
    func needsBackup(_ wallet: Wallet) -> Bool {
        wallet.hasRecoveryPhrase && !wallet.isBackedUp
    }

    var walletsNeedingBackup: Int {
        wallets.filter(needsBackup).count
    }

    // MARK: Data

    /// Reloads balances, prices and history of the selected wallet.
    func refresh() async {
        guard isUnlocked, let wallet = selectedWallet else { return }
        let fiat = settings.fiat
        let testnets = settings.showTestnets
        let portfolio = portfolio
        let activity = activity
        async let balances: Void = portfolio.refresh(wallet: wallet, fiat: fiat, includeTestnets: testnets)
        async let history: Void = activity.refresh(wallet: wallet)
        _ = await (balances, history)
        if case .send(let model) = sheet {
            model.updateRows(sendableRows(for: wallet))
        }
    }

    var assetFilter: AssetFilter {
        AssetFilter(
            hideZeroBalances: settings.hideZeroBalances,
            showTestnets: settings.showTestnets,
            hiddenAssetKeys: settings.hiddenAssetKeys,
            search: ""
        )
    }

    /// Rows that count towards totals and charts: no testnets, no hidden assets.
    var portfolioRows: [AssetRow] {
        var filter = assetFilter
        filter.hideZeroBalances = false
        return filter.apply(to: portfolio.rows(for: selectedWallet))
    }

    var summary: PortfolioSummary {
        PortfolioSummary(rows: portfolioRows)
    }

    /// Total value as shown in the toolbar and the menu bar: masked in
    /// privacy mode, a dash until prices arrive.
    var totalValueText: String {
        guard isUnlocked, selectedWallet != nil else { return "—" }
        if settings.balancesHidden { return Money.mask }
        let summary = summary
        guard summary.pricedRowCount > 0 else { return "—" }
        return Money.fiat(summary.total, currency: settings.fiat)
    }

    private func sendableRows(for wallet: Wallet) -> [AssetRow] {
        var filter = assetFilter
        filter.hideZeroBalances = false
        return filter.apply(to: portfolio.rows(for: wallet))
    }

    // MARK: Actions

    func lock() {
        guard isUnlocked else { return }
        clearSensitiveState()
        let vault = services.vault
        Task { await vault.lock() }
    }

    func toggleBalancesHidden() {
        settings.balancesHidden.toggle()
    }

    func presentSend(assetID: AssetID? = nil) {
        guard isUnlocked, let wallet = selectedWallet else { return }
        guard !wallet.isWatchOnly else {
            showToast("Watch-only wallets cannot send.", symbol: "eye")
            return
        }
        let rows = sendableRows(for: wallet)
        guard !rows.isEmpty else {
            showToast("Balances are still loading.", symbol: "hourglass")
            return
        }
        let preferred = assetID ?? (section == .assets ? selectedAssetID : nil)
        sheet = .send(SendModel(wallet: wallet, rows: rows, initialAssetID: preferred, fiat: settings.fiat, services: services) { [weak self] in
            Task { await self?.refresh() }
        })
    }

    func presentReceive(chainID: ChainID? = nil) {
        guard isUnlocked, let wallet = selectedWallet else { return }
        let chains = portfolio.chains(for: wallet, includeTestnets: settings.showTestnets)
        guard !chains.isEmpty else {
            showToast("Networks are still loading.", symbol: "hourglass")
            return
        }
        let preferred = chainID ?? (section == .assets ? selectedAssetID?.chainID : nil)
        sheet = .receive(ReceiveModel(wallet: wallet, chains: chains, assets: portfolio.assets, initialChainID: preferred, services: services))
    }

    /// "New Wallet" goes straight to a new phrase; "Import Wallet" shows the ways to import.
    func presentAddWallet(creating: Bool) {
        guard isUnlocked, onboarding == nil else { return }
        let model = OnboardingModel(mode: .addWallet, services: services, existingWalletCount: wallets.count) { [weak self] wallet in
            self?.finishOnboarding(with: wallet)
        }
        sheet = .addWallet(model)
        if creating {
            Task { await model.choose(.create) }
        }
    }

    /// A `.json` backup was dropped on the main window: open Add Wallet on
    /// the JSON step with the file loaded.
    func importJSON(from url: URL) {
        guard isUnlocked, onboarding == nil else { return }
        if sheet == nil { presentAddWallet(creating: false) }
        guard case .addWallet(let model) = sheet else { return }
        Task {
            if model.step == .welcome { await model.choose(.importJSON) }
            if model.step == .importJSON { model.loadJSON(from: url) }
        }
    }

    func presentBackup(for wallet: Wallet) {
        guard isUnlocked else { return }
        walletsSettings.begin(.revealPhrase(wallet))
        sheet = .backup(walletsSettings)
    }

    func dismissSheet() {
        if case .send(let model) = sheet { model.cancelObservation() }
        if case .addWallet(let model) = sheet { model.wipeSecrets() }
        if case .backup(let model) = sheet { model.finishSecretAction() }
        sheet = nil
    }

    /// Copies the selected wallet's address: the selected asset's network in
    /// Assets, otherwise its first network.
    func copyAddress() async {
        guard isUnlocked, let wallet = selectedWallet else { return }
        let chains = portfolio.chains(for: wallet, includeTestnets: settings.showTestnets)
        let chain = chains.first { $0.id == selectedAssetID?.chainID && section == .assets } ?? chains.first
        guard let chain else { return }
        await copyAddress(on: chain)
    }

    func copyAddress(on chain: Chain) async {
        guard let wallet = selectedWallet else { return }
        do {
            let address = try await services.wallets.address(of: wallet.id, on: chain.id)
            clipboard.copy(address)
            showToast("\(chain.name) address copied", symbol: "doc.on.doc")
        } catch {
            showToast(ErrorText.message(for: error), symbol: "exclamationmark.triangle")
        }
    }

    /// Opens the wallet's account page on a network's block explorer.
    func showAccountInExplorer(on chain: Chain) async {
        guard let wallet = selectedWallet else { return }
        do {
            let address = try await services.wallets.address(of: wallet.id, on: chain.id)
            openExplorer(chain.explorer?.accountURL(address: address))
        } catch {
            showToast(ErrorText.message(for: error), symbol: "exclamationmark.triangle")
        }
    }

    func hideAsset(_ id: AssetID) {
        settings.setHidden(true, assetID: id)
        if selectedAssetID == id { selectedAssetID = nil }
        showToast("Asset hidden. Show it again in Settings.", symbol: "eye.slash")
    }

    func openExplorer(_ url: URL?) {
        guard let url = AddressFormat.webURL(url) else { return }
        NSWorkspace.shared.open(url)
    }

    func showToast(_ text: String, symbol: String) {
        toastTask?.cancel()
        let toast = Toast(text: text, symbol: symbol)
        self.toast = toast
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled, self?.toast == toast else { return }
            self?.toast = nil
        }
    }

    /// Applies the appearance chosen in Settings to every window of the app.
    func applyAppearance() {
        NSApplication.shared.appearance = settings.appearance.nsAppearance
    }

    /// The user did something; restarts the idle timer.
    func noteActivity() {
        autoLock?.noteActivity()
    }
}

/// Lets a child model call back into the app model that owns it.
@MainActor
private final class ChangeRelay {
    var action: (() async -> Void)?

    func fire() async {
        await action?()
    }
}
