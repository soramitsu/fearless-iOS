import Foundation

extension WarningAlertConfig {
    static func inactiveAlertConfig(bondAmount: String, with locale: Locale) -> WarningAlertConfig {
        WarningAlertConfig(
            title: R.string.localizable.stakingInactiveBond(preferredLanguages: locale.rLanguages),
            iconImage: R.image.iconWarning(),
            text: R.string.localizable.minStakingWarningText(bondAmount, preferredLanguages: locale.rLanguages),
            buttonTitle: R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages),
            blocksUi: false
        )
    }
}
