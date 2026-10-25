import Foundation
import SoraFoundation

/// All recovery copy follows the language selected in the app.
enum RecoveryText {
    static func string(_ key: String, locale: String = LocalizationManager.shared.selectedLocalization) -> String {
        let path = Bundle.main.path(forResource: locale, ofType: "lproj")
            ?? Bundle.main.path(forResource: "en", ofType: "lproj")
        let bundle = path.flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: "recovery." + key, value: nil, table: "Localizable")
    }
}

struct StartupRecoveryViewModel {
    enum Action: Equatable {
        case retry, freshNetworkData, restoreWalletAccess, continueInEnglish, emergencyExport, previousData, help
    }

    let title: String
    let message: String
    let incidentCode: String
    let actions: [Action]
    let locale: String
    private let failure: RootSetupFailure
    private let consecutiveFailures: Int

    init(
        failure: RootSetupFailure,
        consecutiveFailures: Int,
        locale: String = LocalizationManager.shared.selectedLocalization
    ) {
        self.failure = failure
        self.consecutiveFailures = consecutiveFailures
        self.locale = locale
        title = RecoveryText.string("title", locale: locale)
        incidentCode = failure.incidentCode.rawValue
        let networkFailure = failure.phase == .substrateMigration || failure.phase == .substratePreflight
        var body = RecoveryText.string(networkFailure ? "network_message" : "wallet_message", locale: locale)
        if case let .freeStorage(bytes) = failure.recoveryAction {
            body += "\n\n" + String(
                format: RecoveryText.string("free_storage", locale: locale),
                ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .file)
            )
        }
        message = body + "\n\n" + incidentCode
        var available: [Action] = [.retry, .emergencyExport, .previousData]
        if failure.recoveryAction == .continueWithFreshNetworkData || (networkFailure && consecutiveFailures >= 2) {
            available.append(.freshNetworkData)
        }
        if failure
            .recoveryAction == .restoreWalletAccess ||
            (
                (failure.phase == .userStorageMigration || failure.phase == .selectedWalletOpening) &&
                    consecutiveFailures >=
                    2
            ) {
            available.append(.restoreWalletAccess)
        }
        if failure.phase == .languageMigration, consecutiveFailures >= 2 {
            available.append(.continueInEnglish)
        }
        available.append(.help)
        actions = available
    }

    func localized(for locale: String) -> StartupRecoveryViewModel {
        StartupRecoveryViewModel(failure: failure, consecutiveFailures: consecutiveFailures, locale: locale)
    }

    /// No wallet identifiers, addresses, file paths or error descriptions leave
    /// the app with this action. The user sends the message themselves.
    var helpURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = ApplicationConfig.shared.supportEmail
        components.queryItems = [URLQueryItem(name: "body", value: incidentCode)]
        return components.url
    }
}

extension StartupRecoveryViewModel.Action {
    var title: String { localizedTitle(locale: LocalizationManager.shared.selectedLocalization) }

    func localizedTitle(locale: String) -> String {
        switch self {
        case .retry: return RecoveryText.string("retry", locale: locale)
        case .freshNetworkData: return RecoveryText.string("fresh_network", locale: locale)
        case .restoreWalletAccess: return RecoveryText.string("restore_access", locale: locale)
        case .continueInEnglish: return RecoveryText.string("english", locale: locale)
        case .emergencyExport: return RecoveryText.string("export", locale: locale)
        case .previousData: return RecoveryText.string("previous_data", locale: locale)
        case .help: return RecoveryText.string("help", locale: locale)
        }
    }
}
