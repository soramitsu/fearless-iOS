import DesignSystem
import SwiftUI
import WalletCore

/// The Settings window (⌘,).
struct SettingsView: View {
    let app: AppModel

    var body: some View {
        TabView {
            GeneralSettingsTab(app: app)
                .tabItem { Label("General", systemImage: "gearshape") }
            SecuritySettingsTab(app: app)
                .tabItem { Label("Security", systemImage: "lock") }
            WalletsSettingsTab(app: app)
                .tabItem { Label("Wallets", systemImage: "wallet.bifold") }
            NetworksSettingsTab(app: app)
                .tabItem { Label("Networks", systemImage: "point.3.connected.trianglepath.dotted") }
        }
        .frame(width: 640)
        .tint(BrandColor.accent)
        .environment(\.balancesHidden, app.settings.balancesHidden)
        .onAppear { app.start() }
    }
}

/// Shown in place of settings that need an unlocked vault.
struct LockedSettingsPlaceholder: View {
    let what: String

    var body: some View {
        ContentUnavailableView(
            "Fearless Is Locked",
            systemImage: "lock.fill",
            description: Text("Unlock Fearless in its main window to change \(what).")
        )
        .frame(height: 320)
    }
}

// MARK: - General

struct GeneralSettingsTab: View {
    let app: AppModel

    var body: some View {
        let settings = app.settings
        Form {
            Section("Display") {
                Picker("Currency", selection: Binding(get: { settings.fiatCode }, set: { settings.fiatCode = $0 })) {
                    ForEach(FiatCurrency.all) { currency in
                        Text("\(currency.name) (\(currency.code.uppercased()))").tag(currency.code)
                    }
                }
                Picker("Appearance", selection: Binding(get: { settings.appearance }, set: { newValue in
                    settings.appearance = newValue
                    app.applyAppearance()
                })) {
                    ForEach(AppearancePreference.allCases) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Assets") {
                Toggle("Hide zero balances", isOn: Binding(get: { settings.hideZeroBalances }, set: { settings.hideZeroBalances = $0 }))
                Toggle("Show test networks", isOn: Binding(get: { settings.showTestnets }, set: { settings.showTestnets = $0 }))
                LabeledContent("Hidden assets") {
                    HStack(spacing: 8) {
                        Text(settings.hiddenAssetKeys.isEmpty ? "None" : "\(settings.hiddenAssetKeys.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Button("Show All") { settings.hiddenAssetKeys = [] }
                            .disabled(settings.hiddenAssetKeys.isEmpty)
                    }
                }
            }

            Section {
                Toggle("Hide balances", isOn: Binding(get: { settings.balancesHidden }, set: { settings.balancesHidden = $0 }))
            } header: {
                Text("Privacy")
            } footer: {
                FormFootnote("Masks every amount in the window, the toolbar and the menu bar. Shortcut: ⇧⌘H.")
            }

            Section {
                Toggle("Show Fearless in the menu bar", isOn: Binding(get: { settings.menuBarExtraEnabled }, set: { settings.menuBarExtraEnabled = $0 }))
            } header: {
                Text("Menu Bar")
            } footer: {
                FormFootnote("Adds a menu bar item with your total balance, quick address copy and Lock. Off by default.")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(height: 500)
    }
}

// MARK: - Security

struct SecuritySettingsTab: View {
    let app: AppModel

    var body: some View {
        if app.isUnlocked {
            SecuritySettingsForm(app: app, model: app.securitySettings)
        } else {
            LockedSettingsPlaceholder(what: "security settings")
        }
    }
}

private struct SecuritySettingsForm: View {
    let app: AppModel
    @Bindable var model: SecuritySettingsModel

    var body: some View {
        let settings = app.settings
        Form {
            Section("Auto-Lock") {
                Picker("Lock after", selection: Binding(get: { settings.autoLockMinutes }, set: { settings.autoLockMinutes = $0 })) {
                    ForEach(AppSettings.autoLockChoices, id: \.self) { minutes in
                        Text(Self.autoLockTitle(minutes)).tag(minutes)
                    }
                }
                Toggle("Lock when the Mac sleeps", isOn: Binding(get: { settings.lockOnSleep }, set: { settings.lockOnSleep = $0 }))
                Toggle("Lock when the screen locks", isOn: Binding(get: { settings.lockOnScreenLock }, set: { settings.lockOnScreenLock = $0 }))
                LabeledContent("Lock now") {
                    Button("Lock Fearless") { app.lock() }
                }
            }

            Section {
                if let reason = model.biometricsUnavailableReason {
                    LabeledContent("Touch ID") {
                        Text(reason)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                } else {
                    Toggle("Unlock and approve with Touch ID", isOn: Binding(
                        get: { model.biometricsEnabled },
                        set: { model.requestBiometrics($0) }
                    ))
                }
                Toggle("Require approval for every transfer", isOn: .constant(true))
                    .disabled(true)
            } header: {
                Text("Approval")
            } footer: {
                FormFootnote("Every transfer is approved with the app password or Touch ID. This cannot be turned off.")
            }

            Section("App Password") {
                SecureField("Current password", text: $model.currentPassword, prompt: Text("Required"))
                SecureField("New password", text: $model.newPassword, prompt: Text("At least 8 characters"))
                LabeledContent("Strength") {
                    PasswordStrengthMeter(strength: model.newPasswordStrength, isEmpty: model.newPassword.isEmpty)
                }
                SecureField("Confirm new password", text: $model.newPasswordConfirmation, prompt: Text("Type it again"))
                    .onSubmit { Task { await model.changePassword() } }
                if let mismatch = model.passwordMismatchMessage {
                    InlineMessage(mismatch, kind: .error)
                }
                if let error = model.passwordError {
                    InlineMessage(error, kind: .error)
                }
                if model.passwordChanged {
                    InlineMessage("The app password was changed.", kind: .success)
                }
                HStack {
                    Spacer()
                    if model.isWorking { ProgressView().controlSize(.small) }
                    Button("Change Password") { Task { await model.changePassword() } }
                        .disabled(!model.canChangePassword)
                }
            }

            Section {
                LabeledContent("Erase Fearless on this Mac") {
                    Button("Erase All Data…", role: .destructive) { model.beginErase() }
                }
            } footer: {
                FormFootnote("Deletes every wallet, key and setting. Wallets without a backup are lost.")
            }
        }
        .formStyle(.grouped)
        .frame(height: 640)
        .task { await model.load() }
        .sheet(isPresented: $model.isAskingBiometricsPassword) {
            BiometricsPasswordSheet(model: model)
        }
        .sheet(isPresented: $model.isShowingErase) {
            EraseConfirmationView(
                title: "Erase All Data?",
                message: "Fearless returns to first launch. Restore each wallet afterwards from its recovery phrase or backup file.",
                confirmation: $model.eraseConfirmation,
                canErase: model.canErase,
                isWorking: model.isWorking,
                error: model.eraseError,
                onErase: { Task { await model.eraseAll() } },
                onCancel: { model.isShowingErase = false }
            )
        }
    }

    static func autoLockTitle(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "Never"
        case 1: return "1 minute"
        case 60: return "1 hour"
        default: return "\(minutes) minutes"
        }
    }
}

/// Turning Touch ID on or off needs the app password.
private struct BiometricsPasswordSheet: View {
    @Bindable var model: SecuritySettingsModel

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "touchid")
                    .font(.system(size: 34))
                    .foregroundStyle(BrandColor.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.pendingBiometricsValue ? "Turn On Touch ID" : "Turn Off Touch ID").font(.headline)
                    Text("Enter your app password to confirm.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            SecureField("App password", text: $model.biometricsPassword)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { Task { await model.confirmBiometrics() } }
            if let error = model.biometricsError {
                InlineMessage(error, kind: .error)
            }
            HStack {
                Spacer()
                if model.isWorking { ProgressView().controlSize(.small) }
                Button("Cancel") { model.cancelBiometricsRequest() }
                    .keyboardShortcut(.cancelAction)
                Button("Confirm") { Task { await model.confirmBiometrics() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.biometricsPassword.isEmpty || model.isWorking)
            }
        }
        .padding(22)
        .frame(width: 400)
        .onAppear { focused = true }
    }
}

// MARK: - Networks

struct NetworksSettingsTab: View {
    let app: AppModel

    @State private var selection: ChainID?

    var body: some View {
        let chains = app.portfolio.chains
        HStack(spacing: 0) {
            List(chains, selection: $selection) { chain in
                HStack(spacing: 8) {
                    ChainIconView(name: chain.name, iconName: chain.iconName, accentHex: chain.accentHex, size: 20)
                    Text(chain.name).lineLimit(1)
                    if chain.isTestnet {
                        Spacer(minLength: 2)
                        StatusPill("Test", kind: .testnet, showsIcon: false)
                    }
                }
                .tag(chain.id)
            }
            .frame(width: 230)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let chain = chains.first(where: { $0.id == selection }) {
                        Text("\(chain.name) Node")
                            .font(.headline)
                        Text("Fearless reads balances and sends transfers through this node.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        NodesEditorView(model: app.settingsNodes)
                    } else if chains.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Loading networks…").foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Select a network.").foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 440)
        .task {
            await app.portfolio.loadCatalogIfNeeded()
            if selection == nil { selection = app.portfolio.chains.first?.id }
        }
        .task(id: selection) {
            await app.settingsNodes.load(app.portfolio.chains.first { $0.id == selection })
        }
    }
}

/// A quiet explanatory line under a settings section.
struct FormFootnote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
