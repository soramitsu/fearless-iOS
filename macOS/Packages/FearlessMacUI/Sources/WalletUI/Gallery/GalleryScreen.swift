import Foundation

/// The screens the gallery can show in a prepared state. Used by Xcode
/// previews, the snapshot tool and design review. The gallery holds no
/// sample data: every value comes from the services it is given.
public enum GalleryScreen: String, CaseIterable, Sendable, Identifiable {
    case onboardingWelcome
    case onboardingPassword
    case onboardingTouchID
    case onboardingPhraseReveal
    case onboardingPhraseVerify
    case onboardingPhraseImport
    case onboardingJSONImport
    case onboardingConfirm
    case lock
    case portfolio
    case assets
    case activity
    case networks
    case addWallet
    case sendForm
    case sendFormIssue
    case sendReview
    case sendProgress
    case sendFinalized
    case sendFailed
    case sendOutcomeUnknown
    case receive
    case backupPhrase
    case backupDerivation
    case settingsGeneral
    case settingsSecurity
    case settingsWallets
    case settingsNetworks
    case menuBarExtra

    public var id: String { rawValue }

    /// How the screen appears in the app.
    public enum Presentation: Sendable {
        /// Fills the main window.
        case mainWindow
        /// A sheet over the main window.
        case sheet
        /// A tab of the Settings window.
        case settings
        /// The menu bar extra's panel.
        case panel
    }

    public var presentation: Presentation {
        switch self {
        case .onboardingWelcome, .onboardingPassword, .onboardingTouchID, .onboardingPhraseReveal, .onboardingPhraseVerify,
             .onboardingPhraseImport, .onboardingJSONImport, .onboardingConfirm, .lock, .portfolio, .assets, .activity, .networks:
            return .mainWindow
        case .addWallet, .sendForm, .sendFormIssue, .sendReview, .sendProgress, .sendFinalized, .sendFailed, .sendOutcomeUnknown,
             .receive, .backupPhrase, .backupDerivation:
            return .sheet
        case .settingsGeneral, .settingsSecurity, .settingsWallets, .settingsNetworks:
            return .settings
        case .menuBarExtra:
            return .panel
        }
    }

    /// File-name friendly name, e.g. `send-review`.
    public var slug: String {
        var result = ""
        for character in rawValue {
            if character.isUppercase {
                result += "-" + character.lowercased()
            } else {
                result.append(character)
            }
        }
        return result.replacingOccurrences(of: "j-s-o-n", with: "json").replacingOccurrences(of: "i-d", with: "id")
    }

    /// Where the vault must start for the screen to make sense.
    public enum Start: Sendable {
        case firstRun
        case locked
        case unlocked
        /// Unlocked, without any wallet.
        case unlockedEmpty
    }

    public var start: Start {
        switch self {
        case .onboardingWelcome, .onboardingPassword, .onboardingTouchID, .onboardingPhraseReveal, .onboardingPhraseVerify:
            return .firstRun
        case .onboardingPhraseImport, .onboardingJSONImport, .onboardingConfirm:
            return .unlockedEmpty
        case .lock:
            return .locked
        default:
            return .unlocked
        }
    }
}
