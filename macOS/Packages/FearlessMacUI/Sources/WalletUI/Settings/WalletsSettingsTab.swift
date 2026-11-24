import AppKit
import DesignSystem
import SwiftUI
import UniformTypeIdentifiers
import WalletCore

/// Settings ▸ Wallets: rename, back up, export and delete.
struct WalletsSettingsTab: View {
    let app: AppModel

    var body: some View {
        if app.isUnlocked {
            WalletsSettingsContent(app: app, model: app.walletsSettings)
        } else {
            LockedSettingsPlaceholder(what: "wallets")
        }
    }
}

private struct WalletsSettingsContent: View {
    let app: AppModel
    @Bindable var model: WalletsSettingsModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(model.wallets, selection: Binding(get: { model.selectedWalletID }, set: { model.select($0) })) { wallet in
                    HStack(spacing: 8) {
                        WalletAvatar(wallet: wallet, size: 24)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(wallet.name).lineLimit(1)
                            Text(wallet.origin.displayName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 2)
                        if model.needsBackup(wallet) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(BrandColor.warning)
                                .font(.caption)
                                .help("Not backed up")
                                .accessibilityLabel("Not backed up")
                        }
                    }
                    .tag(wallet.id)
                }
                Divider()
                HStack(spacing: 0) {
                    Menu {
                        Button("New Wallet…") { addWallet(creating: true) }
                        Button("Import Wallet…") { addWallet(creating: false) }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 30)
                    .help("Add a wallet")
                    .accessibilityLabel("Add wallet")
                    Button {
                        model.walletPendingDeletion = model.selectedWallet
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 30)
                    .disabled(model.selectedWallet == nil)
                    .help("Delete the selected wallet")
                    .accessibilityLabel("Delete wallet")
                    Spacer()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
            .frame(width: 230)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 440)
        .task { await model.load() }
        .sheet(item: Binding(get: { model.secretAction }, set: { if $0 == nil { model.finishSecretAction() } })) { _ in
            WalletSecretSheet(model: model) { model.finishSecretAction() }
        }
        .confirmationDialog(
            "Delete “\(model.walletPendingDeletion?.name ?? "")”?",
            isPresented: Binding(get: { model.walletPendingDeletion != nil }, set: { if !$0 { model.walletPendingDeletion = nil } }),
            presenting: model.walletPendingDeletion
        ) { wallet in
            Button("Delete Wallet", role: .destructive) { Task { await model.delete(wallet) } }
            Button("Cancel", role: .cancel) { model.walletPendingDeletion = nil }
        } message: { wallet in
            Text(wallet.isWatchOnly
                ? "The address is removed from this Mac. You can add it again at any time."
                : "The keys are removed from this Mac. Without the recovery phrase or a backup file, the funds cannot be reached again.")
        }
    }

    private func addWallet(creating: Bool) {
        app.presentAddWallet(creating: creating)
        NSApplication.shared.windows.first { $0.identifier?.rawValue == FearlessScenes.mainWindowID }?.makeKeyAndOrderFront(nil)
    }

    @ViewBuilder private var detail: some View {
        if let wallet = model.selectedWallet {
            Form {
                Section("Name") {
                    HStack {
                        TextField("Name", text: $model.renameText)
                            .labelsHidden()
                            .onSubmit { Task { await model.rename() } }
                        Button("Rename") { Task { await model.rename() } }
                            .disabled(!model.canRename)
                    }
                }
                Section("About") {
                    LabeledContent("Kind", value: wallet.origin.displayName)
                    LabeledContent("Added", value: wallet.createdAt.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Accounts", value: wallet.accounts.map { $0.ecosystem == .substrate ? "Polkadot ecosystem" : "Ethereum & EVM" }.joined(separator: ", "))
                }
                if wallet.hasRecoveryPhrase {
                    Section {
                        LabeledContent("Status") {
                            if model.needsBackup(wallet) {
                                StatusPill("Not backed up", kind: .warning)
                            } else {
                                StatusPill("Backed up", kind: .success)
                            }
                        }
                        HStack {
                            Button("Show Recovery Phrase…") { model.begin(.revealPhrase(wallet)) }
                            if model.needsBackup(wallet) {
                                Button("Mark as Backed Up") { Task { await model.markBackedUp(wallet) } }
                                    .help("Use this if you already wrote the phrase down.")
                            }
                        }
                    } header: {
                        Text("Backup")
                    } footer: {
                        FormFootnote("Showing the phrase asks for your app password or Touch ID.")
                    }
                }
                if !wallet.isWatchOnly {
                    Section("Export") {
                        LabeledContent("JSON backup file") {
                            Button("Export JSON…") { model.begin(.exportJSON(wallet)) }
                        }
                    }
                }
                Section {
                    LabeledContent("Remove from this Mac") {
                        Button("Delete Wallet…", role: .destructive) { model.walletPendingDeletion = wallet }
                    }
                }
                if let error = model.actionError {
                    InlineMessage(error, kind: .error)
                }
            }
            .formStyle(.grouped)
        } else if let error = model.loadError {
            ErrorStateView("Wallets could not be loaded", message: error) { Task { await model.load() } }
        } else {
            ContentUnavailableView("No Wallet Selected", systemImage: "wallet.bifold", description: Text("Select a wallet, or add one with the plus button."))
        }
    }
}

/// Revealing a phrase or exporting a JSON backup: approval first, then the secret.
struct WalletSecretSheet: View {
    @Bindable var model: WalletsSettingsModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let action = model.secretAction {
                switch action {
                case .revealPhrase(let wallet): reveal(wallet)
                case .exportJSON(let wallet): export(wallet)
                }
            }
        }
        .frame(width: 560)
        .tint(BrandColor.accent)
    }

    // MARK: Reveal

    @ViewBuilder
    private func reveal(_ wallet: Wallet) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recovery Phrase of “\(wallet.name)”")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if model.revealedPhrase.isEmpty {
                Text("Make sure nobody can see your screen, then confirm it is you.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ApprovalField(
                    password: $model.approvalPassword,
                    canUseBiometrics: model.canUseBiometrics,
                    isWorking: model.isWorking,
                    error: model.approvalError,
                    actionTitle: "Show the phrase",
                    canSubmit: model.canApprove,
                    submitPassword: { Task { await model.approve(with: .password(model.approvalPassword)) } },
                    submitBiometrics: { Task { await model.approve(with: .biometrics(reason: "show the recovery phrase")) } }
                )
                footer {
                    if model.isWorking { ProgressView().controlSize(.small) }
                    Button("Cancel", action: onClose).keyboardShortcut(.cancelAction)
                    Button("Show Phrase") { Task { await model.approve(with: .password(model.approvalPassword)) } }
                        .brandProminentButton()
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.approvalPassword.isEmpty || !model.canApprove)
                }
            } else if let verification = model.verification {
                Text("Choose the right word for each position from your written copy.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                PhraseVerifyPanel(verification: verification)
                footer {
                    if model.isWorking { ProgressView().controlSize(.small) }
                    Button("Cancel", action: onClose).keyboardShortcut(.cancelAction)
                    Button("Confirm Backup") { Task { await model.completeVerification() } }
                        .brandProminentButton()
                        .keyboardShortcut(.defaultAction)
                        .disabled(!verification.isComplete || model.isWorking)
                }
            } else {
                Text("Write these words on paper, in order. Anyone who has them can take the funds of this wallet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                PhraseRevealPanel(words: model.revealedPhrase, isRevealed: $model.isPhraseVisible)
                if let derivation = model.revealedDerivation {
                    DerivationDetailsView(options: derivation, isRevealed: model.isPhraseVisible)
                }
                footer {
                    if model.needsBackup(wallet) {
                        Button("Check My Backup…") { model.beginVerification() }
                    }
                    Button("Done", action: onClose)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(22)
    }

    // MARK: Export

    @ViewBuilder
    private func export(_ wallet: Wallet) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Export “\(wallet.name)” as JSON")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if model.exportedJSON == nil {
                Text("The file holds this account's key, encrypted with a password you choose now. It works with Polkadot.js and other Fearless apps.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if wallet.accounts.count > 1 {
                    Picker("Account", selection: $model.exportEcosystem) {
                        ForEach(wallet.accounts.map(\.ecosystem), id: \.self) { ecosystem in
                            Text(ecosystem.displayName).tag(ecosystem)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("Account to export")
                }
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Backup file password")
                    SecureField("Password for the file", text: $model.exportPassword)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Backup file password")
                    PasswordStrengthMeter(strength: PasswordPolicy.evaluate(model.exportPassword), isEmpty: model.exportPassword.isEmpty)
                    SecureField("Confirm the password", text: $model.exportPasswordConfirmation)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Confirm backup file password")
                    if let mismatch = model.exportPasswordMismatch {
                        InlineMessage(mismatch, kind: .error)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Confirm it is you")
                    ApprovalField(
                        password: $model.approvalPassword,
                        canUseBiometrics: model.canUseBiometrics,
                        isWorking: model.isWorking,
                        error: model.approvalError,
                        actionTitle: "Export",
                        canSubmit: model.canApprove,
                        submitPassword: { Task { await model.approve(with: .password(model.approvalPassword)) } },
                        submitBiometrics: { Task { await model.approve(with: .biometrics(reason: "export this wallet")) } }
                    )
                }
                footer {
                    if model.isWorking { ProgressView().controlSize(.small) }
                    Button("Cancel", action: onClose).keyboardShortcut(.cancelAction)
                    Button("Export") { Task { await model.approve(with: .password(model.approvalPassword)) } }
                        .brandProminentButton()
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.approvalPassword.isEmpty || !model.canApprove)
                }
            } else {
                InlineMessage("The backup is ready. Choose where to save it.", kind: .success)
                Text("Keep the file and its password apart. Anyone with both can use this account.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let error = model.approvalError {
                    InlineMessage(error, kind: .error)
                }
                footer {
                    Button("Cancel", action: onClose).keyboardShortcut(.cancelAction)
                    Button("Save As…") { presentSavePanel() }
                        .brandProminentButton()
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(22)
    }

    private func footer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Spacer()
            content()
        }
        .padding(.top, 4)
    }

    private func presentSavePanel() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = model.exportFileName
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.title = "Save Wallet Backup"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated { model.writeExport(to: url) }
        }
    }
}

/// Crypto type and derivation paths of a wallet whose words alone do not
/// restore it. Either path may end in a `///password` part, so the values
/// follow the same reveal rule as the words: hidden until the user reveals
/// the phrase, hidden again when it is hidden.
struct DerivationDetailsView: View {
    let options: DerivationOptions
    let isRevealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("This wallet also needs these settings to be restored. Write them down with the words.", systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(BrandColor.warning)
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                row("Polkadot key type", options.substrateCryptoType.displayName)
                row("Polkadot derivation path", options.substrateDerivationPath.isEmpty ? "None" : options.substrateDerivationPath)
                row("Ethereum derivation path", options.evmDerivationPath)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColor.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(BrandColor.warning.opacity(0.3), lineWidth: 0.5))
    }

    private func row(_ label: String, _ value: String) -> some View {
        let presentation = Self.presentation(of: value, isRevealed: isRevealed)
        let text = Text(presentation.shown)
            .font(.system(.callout, design: .monospaced))
            .accessibilityLabel(label)
            .accessibilityValue(isRevealed ? value : "Hidden")
        return GridRow {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                if presentation.isSelectable {
                    text.textSelection(.enabled)
                } else {
                    text.textSelection(.disabled)
                }
                if presentation.copiesConcealed {
                    CopyButton(value: value, label: "Copy \(label)", concealed: true)
                }
            }
        }
    }

    /// How a value is shown. A revealed path with a `///password` cannot be
    /// selected: it is copied only with its button, which marks the copy
    /// concealed, keeps it on this Mac and clears it after 60 seconds.
    struct Presentation: Equatable {
        let shown: String
        let isSelectable: Bool
        let copiesConcealed: Bool
    }

    static func presentation(of value: String, isRevealed: Bool) -> Presentation {
        guard isRevealed else { return Presentation(shown: "••••••", isSelectable: false, copiesConcealed: false) }
        let holdsPassword = DerivationPath.holdsPassword(value)
        return Presentation(shown: value, isSelectable: !holdsPassword, copiesConcealed: holdsPassword)
    }
}
