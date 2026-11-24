import Foundation
import Observation
import WalletCore

/// A secret action in Settings ▸ Wallets that needs the user's approval first.
enum WalletSecretAction: Identifiable, Equatable {
    case revealPhrase(Wallet)
    case exportJSON(Wallet)

    var id: String {
        switch self {
        case .revealPhrase(let wallet): return "reveal-\(wallet.id)"
        case .exportJSON(let wallet): return "export-\(wallet.id)"
        }
    }

    var wallet: Wallet {
        switch self {
        case .revealPhrase(let wallet), .exportJSON(let wallet): return wallet
        }
    }
}

/// Settings ▸ Wallets: rename, back up, export and delete.
@MainActor
@Observable
final class WalletsSettingsModel {
    @ObservationIgnored private let services: WalletServices
    @ObservationIgnored private let onChanged: () async -> Void

    private(set) var wallets: [Wallet] = []
    private(set) var loadError: String?
    var selectedWalletID: WalletID?

    var renameText = ""
    private(set) var actionError: String?
    private(set) var isWorking = false

    // Approval for reveal and export.
    var secretAction: WalletSecretAction?
    var approvalPassword = ""
    private(set) var approvalError: String?
    private(set) var biometrics: BiometricsAvailability = .unavailable(reason: "")

    // Reveal.
    /// The phrase with its derivation options, after approval.
    private(set) var revealedBackup: MnemonicBackup?
    var isPhraseVisible = false
    private(set) var verification: PhraseVerification?

    // Export.
    var exportEcosystem: Ecosystem = .substrate
    var exportPassword = ""
    var exportPasswordConfirmation = ""
    /// The exported keystore, waiting for the save panel.
    private(set) var exportedJSON: Data?

    var walletPendingDeletion: Wallet?

    init(services: WalletServices, onChanged: @escaping () async -> Void) {
        self.services = services
        self.onChanged = onChanged
    }

    var selectedWallet: Wallet? {
        wallets.first { $0.id == selectedWalletID }
    }

    /// The revealed words; empty until the user approved.
    var revealedPhrase: [String] { revealedBackup?.words ?? [] }

    /// Crypto type and paths, when the words alone do not restore the wallet.
    var revealedDerivation: DerivationOptions? {
        guard let backup = revealedBackup, backup.needsDerivationDetails else { return nil }
        return backup.options
    }

    func needsBackup(_ wallet: Wallet) -> Bool {
        wallet.hasRecoveryPhrase && !wallet.isBackedUp
    }

    func load() async {
        do {
            wallets = try await services.wallets.wallets()
            loadError = nil
            if selectedWallet == nil { selectedWalletID = wallets.first?.id }
            renameText = selectedWallet?.name ?? ""
        } catch {
            loadError = ErrorText.message(for: error)
        }
        biometrics = await services.vault.biometricsAvailability()
    }

    func select(_ id: WalletID?) {
        selectedWalletID = id
        renameText = selectedWallet?.name ?? ""
        actionError = nil
    }

    var canRename: Bool {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name != selectedWallet?.name && !isWorking
    }

    func rename() async {
        guard canRename, let wallet = selectedWallet else { return }
        await perform {
            try await self.services.wallets.renameWallet(wallet.id, to: self.renameText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func delete(_ wallet: Wallet) async {
        await perform {
            try await self.services.wallets.deleteWallet(wallet.id)
        }
        walletPendingDeletion = nil
    }

    func markBackedUp(_ wallet: Wallet) async {
        await perform {
            try await self.services.wallets.markBackedUp(wallet.id)
        }
    }

    private func perform(_ work: () async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await work()
            actionError = nil
            await load()
            await onChanged()
        } catch {
            actionError = ErrorText.message(for: error)
        }
    }

    // MARK: Reveal and export

    func begin(_ action: WalletSecretAction) {
        clearSecrets()
        if case .exportJSON(let wallet) = action {
            exportEcosystem = wallet.account(for: .substrate) != nil ? .substrate : .evm
        }
        secretAction = action
    }

    var canUseBiometrics: Bool { biometrics == .enabled }

    var exportPasswordMismatch: String? {
        guard !exportPasswordConfirmation.isEmpty, exportPassword != exportPasswordConfirmation else { return nil }
        return "The backup passwords do not match."
    }

    var canApprove: Bool {
        guard !isWorking, let secretAction else { return false }
        if case .exportJSON = secretAction {
            return PasswordPolicy.isAcceptable(exportPassword) && exportPassword == exportPasswordConfirmation
        }
        return true
    }

    func approve(with approval: UserApproval) async {
        guard canApprove, let action = secretAction else { return }
        isWorking = true
        approvalError = nil
        defer { isWorking = false }
        do {
            switch action {
            case .revealPhrase(let wallet):
                revealedBackup = try await services.wallets.exportMnemonic(wallet.id, approval: approval)
                isPhraseVisible = false
            case .exportJSON(let wallet):
                exportedJSON = try await services.wallets.exportJSON(wallet.id, ecosystem: exportEcosystem, approval: approval, exportPassword: exportPassword)
            }
            approvalPassword = ""
        } catch WalletError.biometricsCancelled {
            // Dismissed Touch ID; nothing to report.
        } catch {
            approvalPassword = ""
            approvalError = ErrorText.message(for: error)
        }
    }

    func beginVerification() {
        guard !revealedPhrase.isEmpty else { return }
        isPhraseVisible = false
        verification = PhraseVerification(words: revealedPhrase, wordList: services.wallets.mnemonicWordList)
    }

    func completeVerification() async {
        guard verification?.isComplete == true, let wallet = secretAction?.wallet else { return }
        await markBackedUp(wallet)
        finishSecretAction()
    }

    /// Suggested file name for the exported keystore.
    var exportFileName: String {
        let name = secretAction?.wallet.name ?? "wallet"
        let safe = name.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return "fearless-\(String(safe).lowercased())-\(exportEcosystem.rawValue).json"
    }

    /// Writes the exported keystore where the save panel pointed.
    func writeExport(to url: URL) {
        guard let exportedJSON else { return }
        do {
            try exportedJSON.write(to: url, options: [.atomic])
            finishSecretAction()
        } catch {
            approvalError = "The file could not be saved."
        }
    }

    func finishSecretAction() {
        clearSecrets()
        secretAction = nil
    }

    /// Drops every secret this model holds.
    func clearSecrets() {
        approvalPassword = ""
        approvalError = nil
        revealedBackup = nil
        isPhraseVisible = false
        verification = nil
        exportPassword = ""
        exportPasswordConfirmation = ""
        exportedJSON = nil
    }

    func reset() {
        finishSecretAction()
        wallets = []
        selectedWalletID = nil
        renameText = ""
        walletPendingDeletion = nil
    }
}
