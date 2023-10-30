import Foundation
import SoraFoundation
import WalletConnectSign

extension AutoNamespacesError: LocalizedError {
    public var errorDescription: String? {
        let localizationManager = LocalizationManager.shared
        let preferredLanguages = localizationManager.selectedLocale.rLanguages
        switch self {
        case .requiredChainsNotSatisfied:
            return R.string.localizable.requiredChainsNotSatisfied(preferredLanguages: preferredLanguages)
        case .requiredAccountsNotSatisfied:
            return R.string.localizable.requiredAccountsNotSatisfied(preferredLanguages: preferredLanguages)
        case .requiredMethodsNotSatisfied:
            return R.string.localizable.requiredMethodsNotSatisfied(preferredLanguages: preferredLanguages)
        case .requiredEventsNotSatisfied:
            return R.string.localizable.requiredEventsNotSatisfied(preferredLanguages: preferredLanguages)
        }
    }
}
