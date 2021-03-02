import Foundation

protocol StakingErrorPresentable {
    func presentBalanceTooHigh(from view: ControllerBackedProtocol, locale: Locale?)
    func presentFeeNotReceived(from view: ControllerBackedProtocol, locale: Locale?)
}

extension StakingErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentBalanceTooHigh(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable.stakingAmountTooBigError(preferredLanguages: locale?.rLanguages)
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
}
