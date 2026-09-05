import Foundation

extension AccountImportSource {
    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .mnemonic:
            return R.string.localizable
                .importMnemonic(preferredLanguages: locale.rLanguages)
        case .legacyTonMnemonic:
            return NSLocalizedString("import.legacy_ton_phrase", value: "Legacy TON recovery phrase", comment: "Native TON recovery format")
        case .seed:
            return R.string.localizable
                .importRawSeed(preferredLanguages: locale.rLanguages)
        case .keystore:
            return R.string.localizable
                .importRecoveryJson(preferredLanguages: locale.rLanguages)
        }
    }
}
