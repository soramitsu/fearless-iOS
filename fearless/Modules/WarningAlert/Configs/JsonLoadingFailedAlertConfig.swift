import Foundation

extension WarningAlertConfig {
    static func connectionProblemAlertConfig(with locale: Locale) -> WarningAlertConfig {
        WarningAlertConfig(
            title: R.string.localizable.connectionProblemsText(preferredLanguages: locale.rLanguages),
            iconImage: R.image.iconWarning(),
            text: R.string.localizable.appVersionJsonLoadingFailed(preferredLanguages: locale.rLanguages),
            buttonTitle: R.string.localizable.commonRetry(preferredLanguages: locale.rLanguages),
            blocksUi: true
        )
    }
}
