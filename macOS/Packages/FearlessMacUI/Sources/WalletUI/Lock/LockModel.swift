import Foundation
import Observation
import WalletCore

/// The lock screen: password or Touch ID unlock, and the "Forgot password"
/// path that erases everything after a typed confirmation.
@MainActor
@Observable
final class LockModel {
    /// What the user must type before erasing.
    static let eraseConfirmationWord = "ERASE"

    @ObservationIgnored private let vault: any VaultServicing

    var password = ""
    private(set) var isWorking = false
    private(set) var errorMessage: String?
    /// Incremented on every wrong password; drives the shake.
    private(set) var failedAttempts = 0
    private(set) var biometrics: BiometricsAvailability = .unavailable(reason: "")

    var isShowingErase = false
    var eraseConfirmation = ""
    private(set) var isErasing = false
    private(set) var eraseError: String?

    init(vault: any VaultServicing) {
        self.vault = vault
    }

    var canUseBiometrics: Bool { biometrics == .enabled }
    var canUnlock: Bool { !password.isEmpty && !isWorking }
    var canErase: Bool { eraseConfirmation == Self.eraseConfirmationWord && !isErasing }

    func load() async {
        biometrics = await vault.biometricsAvailability()
    }

    func unlockWithPassword() async {
        guard canUnlock else { return }
        await unlock(.password(password))
    }

    func unlockWithBiometrics() async {
        guard canUseBiometrics, !isWorking else { return }
        await unlock(.biometrics(reason: "unlock Fearless Wallet"))
    }

    private func unlock(_ approval: UserApproval) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await vault.unlock(approval)
            password = ""
        } catch WalletError.biometricsCancelled {
            // The user dismissed Touch ID; nothing to report.
        } catch {
            if case .password = approval {
                password = ""
                failedAttempts += 1
            }
            errorMessage = ErrorText.message(for: error)
        }
    }

    func beginErase() {
        eraseConfirmation = ""
        eraseError = nil
        isShowingErase = true
    }

    func cancelErase() {
        eraseConfirmation = ""
        isShowingErase = false
    }

    /// Deletes every wallet and setting of the engine. The vault then
    /// reports `.uninitialized` and the app returns to first launch.
    func eraseAll() async {
        guard canErase else { return }
        isErasing = true
        eraseError = nil
        defer { isErasing = false }
        do {
            try await vault.eraseAllData()
            eraseConfirmation = ""
            isShowingErase = false
        } catch {
            eraseError = ErrorText.message(for: error)
        }
    }
}
