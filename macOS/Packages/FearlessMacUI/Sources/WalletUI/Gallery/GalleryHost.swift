import DesignSystem
import SwiftUI
import WalletCore

/// Builds one screen in a prepared state over the services it is given
/// (for example the in-memory preview services). It drives the real view
/// models through the same calls the user's actions make.
@MainActor
public final class GalleryHost {
    /// Text the host types into fields. All of it is supplied by the caller.
    public struct Inputs: Sendable {
        /// The app password of the vault the services start with.
        public var password: String
        /// A valid recipient for the first sendable asset.
        public var recipient: String
        /// A recipient on another network, for the wrong-network example.
        public var wrongNetworkRecipient: String
        /// Words to fill into the import grid.
        public var importWords: [String]

        public init(password: String, recipient: String, wrongNetworkRecipient: String, importWords: [String]) {
            self.password = password
            self.recipient = recipient
            self.wrongNetworkRecipient = wrongNetworkRecipient
            self.importWords = importWords
        }
    }

    public let screen: GalleryScreen
    public let app: AppModel
    private let inputs: Inputs
    private var sendModel: SendModel?
    private var receiveModel: ReceiveModel?
    private var addWalletModel: OnboardingModel?

    public init(screen: GalleryScreen, services: WalletServices, settings: AppSettings, inputs: Inputs) {
        self.screen = screen
        self.inputs = inputs
        app = AppModel(services: services, settings: settings)
    }

    /// Brings the models to the state the screen shows. Returns false when
    /// the state could not be reached in time.
    @discardableResult
    public func prepare(timeout: Duration = .seconds(20)) async -> Bool {
        app.start(monitorSystem: false)
        switch screen.start {
        case .firstRun, .unlockedEmpty:
            guard await wait(timeout, { self.app.route == .onboarding && self.app.onboarding != nil }) else { return false }
        case .locked:
            guard await wait(timeout, { self.app.route == .locked }) else { return false }
        case .unlocked:
            guard await wait(timeout, { self.app.route == .main && self.app.selectedWallet != nil }) else { return false }
            guard await wait(timeout, { self.app.portfolio.lastUpdated != nil && self.app.activity.state != .loading && self.app.activity.state != .idle }) else { return false }
        }
        return await enterState(timeout)
    }

    private func enterState(_ timeout: Duration) async -> Bool {
        switch screen {
        case .onboardingWelcome, .lock, .portfolio:
            return true

        case .onboardingPassword:
            guard let model = app.onboarding else { return false }
            await model.choose(.create)
            model.password = inputs.password
            model.passwordConfirmation = String(inputs.password.dropLast(2))
            return model.step == .password

        case .onboardingTouchID:
            guard let model = app.onboarding else { return false }
            await model.choose(.create)
            await setPassword(model)
            return model.step == .biometrics

        case .onboardingPhraseReveal, .onboardingPhraseVerify:
            guard let model = app.onboarding else { return false }
            await model.choose(.create)
            await setPassword(model)
            if model.step == .biometrics { await model.skipBiometrics() }
            guard await wait(timeout, { !model.phrase.isEmpty }) else { return false }
            if screen == .onboardingPhraseReveal {
                model.isPhraseRevealed = true
                return model.step == .phraseReveal
            }
            model.beginVerification()
            if let verification = model.verification, let first = verification.challenges.first {
                verification.select(model.phrase[first.position], for: first.position)
                if let second = verification.challenges.dropFirst().first,
                   let wrong = second.options.first(where: { $0 != model.phrase[second.position] }) {
                    verification.select(wrong, for: second.position)
                }
            }
            return model.step == .phraseVerify

        case .onboardingPhraseImport:
            guard let model = app.onboarding else { return false }
            await model.choose(.importPhrase)
            let entry = model.phraseEntry
            entry.setText(inputs.importWords.joined(separator: " "), at: 0)
            // One misspelt word and one being typed, to show both states.
            if entry.wordCount > 6 {
                entry.setText("fearles", at: 3)
                let partial = String((inputs.importWords[safe: 6] ?? "cru").prefix(3))
                entry.setText(partial, at: 6)
                entry.focusedIndex = 6
            }
            return model.step == .importPhrase

        case .onboardingJSONImport:
            guard let model = app.onboarding else { return false }
            await model.choose(.importJSON)
            return model.step == .importJSON

        case .onboardingConfirm:
            guard let model = app.onboarding else { return false }
            await model.choose(.importPhrase)
            model.phraseEntry.setText(inputs.importWords.joined(separator: " "), at: 0)
            await model.phraseEntry.revalidate()
            await model.continueImport()
            return model.step == .confirm

        case .assets:
            app.section = .assets
            app.settings.inspectorVisible = true
            app.selectedAssetID = app.portfolioRows.first(where: \.hasBalance)?.id
            return true

        case .activity:
            app.section = .activity
            app.settings.inspectorVisible = true
            app.selectedActivityID = app.activity.items.first?.id
            return true

        case .networks:
            app.section = .networks
            app.settings.inspectorVisible = true
            app.selectedNetworkID = app.portfolio.failedChains.first?.chain.id ?? app.portfolio.chains.first?.id
            await app.networkNodes.load(app.portfolio.chains.first { $0.id == app.selectedNetworkID })
            return true

        case .addWallet:
            let model = OnboardingModel(mode: .addWallet, services: app.services, existingWalletCount: app.wallets.count) { _ in }
            addWalletModel = model
            return true

        case .sendForm, .sendFormIssue, .sendReview, .sendProgress, .sendFinalized, .sendFailed, .sendOutcomeUnknown:
            return await prepareSend(timeout)

        case .receive:
            guard let wallet = app.selectedWallet else { return false }
            let chains = app.portfolio.chains(for: wallet, includeTestnets: false)
            let model = ReceiveModel(wallet: wallet, chains: chains, assets: app.portfolio.assets, initialChainID: nil, services: app.services)
            receiveModel = model
            await model.load()
            return model.address != nil

        case .backupPhrase:
            guard let wallet = app.wallets.first(where: { app.needsBackup($0) }) ?? app.selectedWallet else { return false }
            let model = app.walletsSettings
            model.begin(.revealPhrase(wallet))
            await model.approve(with: .password(inputs.password))
            model.isPhraseVisible = true
            return !model.revealedPhrase.isEmpty

        case .backupDerivation:
            // The selected wallet; its backup shows the derivation settings when it has any.
            guard let wallet = app.selectedWallet else { return false }
            let model = app.walletsSettings
            model.begin(.revealPhrase(wallet))
            await model.approve(with: .password(inputs.password))
            model.isPhraseVisible = true
            return !model.revealedPhrase.isEmpty

        case .settingsGeneral:
            return true

        case .settingsSecurity:
            await app.securitySettings.load()
            return true

        case .settingsWallets:
            await app.walletsSettings.load()
            return true

        case .settingsNetworks:
            await app.settingsNodes.load(app.portfolio.chains.first)
            return true

        case .menuBarExtra:
            return true
        }
    }

    private func setPassword(_ model: OnboardingModel) async {
        model.password = inputs.password
        model.passwordConfirmation = inputs.password
        await model.submitPassword()
    }

    private func prepareSend(_ timeout: Duration) async -> Bool {
        guard let wallet = app.selectedWallet else { return false }
        let rows = app.portfolioRows
        let model = SendModel(wallet: wallet, rows: rows, initialAssetID: rows.first(where: \.hasBalance)?.id, fiat: app.settings.fiat, services: app.services, debounce: .zero)
        sendModel = model
        await model.prepareNow()
        if screen == .sendForm { return true }
        if screen == .sendFormIssue {
            model.recipientText = inputs.wrongNetworkRecipient
            model.amountText = "999999"
            await model.prepareNow()
            return true
        }
        model.recipientText = inputs.recipient
        model.amountText = "25"
        await model.review()
        guard model.stage == .review else { return false }
        if screen == .sendReview { return true }
        model.approvalPassword = inputs.password
        let submission = Task { await model.approveWithPassword() }
        _ = submission
        switch screen {
        case .sendProgress:
            return await wait(timeout) { model.sealStage >= .sent }
        case .sendFinalized:
            return await wait(timeout) { model.sealStage == .finalized }
        case .sendFailed:
            return await wait(timeout) { model.didFail }
        case .sendOutcomeUnknown:
            return await wait(timeout) { model.isOutcomeUnknown }
        default:
            return true
        }
    }

    private func wait(_ timeout: Duration, _ condition: @MainActor () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while !condition() {
            if clock.now >= deadline { return false }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return true
    }

    /// The screen's root view. Main-window screens include the whole window
    /// content; sheets, settings tabs and the panel are returned on their own.
    public var view: AnyView {
        let base: AnyView
        switch screen {
        case .onboardingWelcome, .onboardingPassword, .onboardingTouchID, .onboardingPhraseReveal, .onboardingPhraseVerify,
             .onboardingPhraseImport, .onboardingJSONImport, .onboardingConfirm, .lock, .portfolio, .assets, .activity, .networks:
            base = AnyView(RootView(app: app).frame(minWidth: 900, minHeight: 600))
        case .addWallet:
            base = AnyView(Group {
                if let addWalletModel { AddWalletSheet(model: addWalletModel) {} }
            })
        case .sendForm, .sendFormIssue, .sendReview, .sendProgress, .sendFinalized, .sendFailed, .sendOutcomeUnknown:
            base = AnyView(Group {
                if let sendModel { SendSheet(model: sendModel) {} }
            })
        case .receive:
            base = AnyView(Group {
                if let receiveModel { ReceiveSheet(model: receiveModel, onShowExplorer: { _ in }) {} }
            })
        case .backupPhrase, .backupDerivation:
            base = AnyView(WalletSecretSheet(model: app.walletsSettings) {})
        case .settingsGeneral:
            base = AnyView(GeneralSettingsTab(app: app).frame(width: 640))
        case .settingsSecurity:
            base = AnyView(SecuritySettingsTab(app: app).frame(width: 640))
        case .settingsWallets:
            base = AnyView(WalletsSettingsTab(app: app).frame(width: 640))
        case .settingsNetworks:
            base = AnyView(NetworksSettingsTab(app: app).frame(width: 640))
        case .menuBarExtra:
            base = AnyView(MenuBarPanel(app: app))
        }
        return AnyView(
            base
                .tint(BrandColor.accent)
                .environment(\.balancesHidden, app.settings.balancesHidden)
        )
    }
}

/// A gallery screen as a SwiftUI view that prepares itself, for previews.
public struct GalleryView: View {
    @State private var host: GalleryHost
    @State private var ready = false

    public init(screen: GalleryScreen, services: WalletServices, settings: AppSettings, inputs: GalleryHost.Inputs) {
        _host = State(initialValue: GalleryHost(screen: screen, services: services, settings: settings, inputs: inputs))
    }

    public var body: some View {
        Group {
            if ready {
                host.view
            } else {
                LoadingStateView("Preparing…")
            }
        }
        .task {
            await host.prepare()
            ready = true
        }
    }
}
