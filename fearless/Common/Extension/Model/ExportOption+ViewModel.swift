import Foundation
import SSFModels

extension ExportOption {
    func titleForLocale(_ locale: Locale, ecosystem: Ecosystem?) -> String {
        switch self {
        case .mnemonic:
            return R.string.localizable
                .importMnemonic(preferredLanguages: locale.rLanguages)
        case .keystore:
            switch ecosystem {
            case .substrate:
                return R.string.localizable.importSubstrateRecoveryJson(preferredLanguages: locale.rLanguages)
            case .ethereumBased, .ethereum:
                return R.string.localizable.importEthereumRecoveryJson(preferredLanguages: locale.rLanguages)
            case .ton:
                return ""
            case .none:
                return R.string.localizable.importRecoveryJson(preferredLanguages: locale.rLanguages)
            }

        case .seed:
            switch ecosystem {
            case .substrate:
                return R.string.localizable.accountImportSubstrateRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
            case .ethereumBased, .ethereum:
                return R.string.localizable.accountImportEthereumRawSeedPlaceholder(preferredLanguages: locale.rLanguages)
            case .ton:
                return ""
            case .none:
                return R.string.localizable.importRawSeed(preferredLanguages: locale.rLanguages)
            }
        }
    }
}
