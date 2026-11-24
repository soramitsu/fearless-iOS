import Foundation
import Observation
import WalletCore

/// Settings ▸ Security: Touch ID, changing the app password and erasing all data.
@MainActor
@Observable
final class SecuritySettingsModel {
    @ObservationIgnored private let vault: any VaultServicing

    private(set) var biometrics: BiometricsAvailability = .unavailable(reason: "")
    private(set) var isWorking = false

    // Touch ID toggle (needs the password).
    var isAskingBiometricsPassword = false
    var biometricsPassword = ""
    private(set) var pendingBiometricsValue = false
    private(set) var biometricsError: String?

    // Change password.
    var currentPassword = ""
    var newPassword = ""
    var newPasswordConfirmation = ""
    private(set) var passwordError: String?
    private(set) var passwordChanged = false

    // Erase.
    var isShowingErase = false
    var eraseConfirmation = ""
    private(set) var eraseError: String?

    init(vault: any VaultServicing) {
        self.vault = vault
    }

    func load() async {
        biometrics = await vault.biometricsAvailability()
    }

    var biometricsEnabled: Bool { biometrics == .enabled }

    var biometricsUnavailableReason: String? {
        if case .unavailable(let reason) = biometrics {
            return reason.isEmpty ? "Touch ID is not available for Fearless on this Mac." : reason
        }
        return nil
    }

    /// The switch was flipped: ask for the password before changing anything.
    func requestBiometrics(_ enabled: Bool) {
        guard biometricsUnavailableReason == nil else { return }
        pendingBiometricsValue = enabled
        biometricsPassword = ""
        biometricsError = nil
        isAskingBiometricsPassword = true
    }

    func cancelBiometricsRequest() {
        biometricsPassword = ""
        isAskingBiometricsPassword = false
    }

    func confirmBiometrics() async {
        guard !biometricsPassword.isEmpty, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await vault.setBiometricsEnabled(pendingBiometricsValue, password: biometricsPassword)
            biometricsPassword = ""
            isAskingBiometricsPassword = false
            biometrics = await vault.biometricsAvailability()
        } catch {
            biometricsPassword = ""
            biometricsError = ErrorText.message(for: error)
        }
    }

    var newPasswordStrength: PasswordStrength { PasswordPolicy.evaluate(newPassword) }

    var passwordMismatchMessage: String? {
        guard !newPasswordConfirmation.isEmpty, newPassword != newPasswordConfirmation else { return nil }
        return "The new passwords do not match."
    }

    var canChangePassword: Bool {
        !currentPassword.isEmpty && newPasswordStrength >= .fair && newPassword == newPasswordConfirmation && !isWorking
    }

    func changePassword() async {
        guard canChangePassword else { return }
        isWorking = true
        passwordChanged = false
        defer { isWorking = false }
        do {
            try await vault.changePassword(current: currentPassword, new: newPassword)
            currentPassword = ""
            newPassword = ""
            newPasswordConfirmation = ""
            passwordError = nil
            passwordChanged = true
        } catch {
            currentPassword = ""
            passwordError = ErrorText.message(for: error)
        }
    }

    var canErase: Bool { eraseConfirmation == LockModel.eraseConfirmationWord && !isWorking }

    func beginErase() {
        eraseConfirmation = ""
        eraseError = nil
        isShowingErase = true
    }

    func eraseAll() async {
        guard canErase else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await vault.eraseAllData()
            eraseConfirmation = ""
            isShowingErase = false
        } catch {
            eraseError = ErrorText.message(for: error)
        }
    }

    /// Forgets typed secrets (the window closed or the app locked).
    func clearSecrets() {
        biometricsPassword = ""
        currentPassword = ""
        newPassword = ""
        newPasswordConfirmation = ""
        eraseConfirmation = ""
        isAskingBiometricsPassword = false
        isShowingErase = false
        passwordChanged = false
    }
}
