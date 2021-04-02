import Foundation

protocol StakingErrorPresentable {
    func presentAmountTooHigh(from view: ControllerBackedProtocol, locale: Locale?)
    func presentAmountTooLow(value: String, from view: ControllerBackedProtocol, locale: Locale?)
    func presentFeeNotReceived(from view: ControllerBackedProtocol, locale: Locale?)
    func presentExtrinsicFailed(from view: ControllerBackedProtocol, locale: Locale?)
    func presentMissingController(
        from view: ControllerBackedProtocol,
        address: AccountAddress,
        locale: Locale?
    )
}

extension StakingErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentAmountTooHigh(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable
            .stakingAmountTooBigError(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentAmountTooLow(value: String, from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable.stakingSetupAmountTooLow(value)
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentFeeNotReceived(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable.feeNotYetLoadedMessage(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.feeNotYetLoadedTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentExtrinsicFailed(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable.stakingSetupFailedMessage(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentMissingController(
        from view: ControllerBackedProtocol,
        address: AccountAddress,
        locale: Locale?
    ) {
        let message = R.string.localizable
            .stakingControllerMissingMessage(address, preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
