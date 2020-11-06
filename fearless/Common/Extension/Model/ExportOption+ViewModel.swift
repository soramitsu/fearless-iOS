import Foundation

extension ExportOption {
    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .mnemonic:
            return R.string.localizable
                .importMnemonic(preferredLanguages: locale.rLanguages)
        case .keystore:
            return R.string.localizable
                .importRecoveryJson(preferredLanguages: locale.rLanguages)
        }
    }
}
