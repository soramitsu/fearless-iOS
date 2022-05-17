import Foundation

extension WarningAlertConfig {
    static func unsupportedAppVersionConfig(with locale: Locale) -> WarningAlertConfig {
        WarningAlertConfig(
            title: R.string.localizable.updateNeededText(preferredLanguages: locale.rLanguages),
            iconImage: R.image.iconWarning(),
            text: R.string.localizable.appVersionUnsupportedText(preferredLanguages: locale.rLanguages),
            buttonTitle: R.string.localizable.commonUpdate(preferredLanguages: locale.rLanguages),
            blocksUi: true
        )
    }
}
