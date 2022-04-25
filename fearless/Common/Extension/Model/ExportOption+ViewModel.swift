import Foundation

extension ExportOption {
    func titleForLocale(_ locale: Locale, ethereumBased: Bool?) -> String {
        switch self {
        case .mnemonic:
            return R.string.localizable
                .importMnemonic(preferredLanguages: locale.rLanguages)
        case .keystore:
            guard let ethereumBased = ethereumBased else {
                return R.string.localizable
                    .importRecoveryJson(preferredLanguages: locale.rLanguages)
            }

            return ethereumBased
                ? R.string.localizable.importEthereumRecoveryJson(preferredLanguages: locale.rLanguages)
                : R.string.localizable.importSubstrateRecoveryJson(preferredLanguages: locale.rLanguages)
        case .seed:
            guard let ethereumBased = ethereumBased else {
                return R.string.localizable
                    .importRawSeed(preferredLanguages: locale.rLanguages)
            }

            return ethereumBased
                ? R.string.localizable.accountImportEthereumRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
                : R.string.localizable.accountImportSubstrateRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
        }
    }
}
