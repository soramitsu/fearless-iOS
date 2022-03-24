import Foundation

extension WarningAlertConfig {
    static func unsupportedChainConfig(with locale: Locale) -> WarningAlertConfig {
        WarningAlertConfig(
            title: R.string.localizable.updateNeededText(preferredLanguages: locale.rLanguages),
            iconImage: R.image.iconWarning(),
            text: R.string.localizable.chainUnsupportedText(preferredLanguages: locale.rLanguages),
            buttonTitle: R.string.localizable.commonUpdate(preferredLanguages: locale.rLanguages),
            blocksUi: false
        )
    }
}
