import Foundation

enum ExperimentalOption: Int, CaseIterable {
    case notifications
    case signer
}

extension ExperimentalOption {
    func title(for locale: Locale) -> String {
        switch self {
        case .notifications:
            return R.string.localizable.experimentalOptionNotifications(preferredLanguages: locale.rLanguages)
        case .signer:
            return R.string.localizable.experimentalOptionSigners(preferredLanguages: locale.rLanguages)
        }
    }
}
