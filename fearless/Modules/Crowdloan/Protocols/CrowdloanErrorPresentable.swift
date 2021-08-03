import Foundation

protocol CrowdloanErrorPresentable: BaseErrorPresentable {
    func presentMinimalBalanceContributionError(
        _ value: String,
        from view: ControllerBackedProtocol,
        locale: Locale?
    )

    func presentCapReachedError(from view: ControllerBackedProtocol, locale: Locale?)

    func presentAmountExceedsCapError(_ amount: String, from view: ControllerBackedProtocol, locale: Locale?)

    func presentCrowdloanEnded(from view: ControllerBackedProtocol, locale: Locale?)

    func presentCrowdloanPrivateNotSupported(from view: ControllerBackedProtocol, locale: Locale?)
}

extension CrowdloanErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentMinimalBalanceContributionError(
        _ value: String,
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let message = R.string.localizable.crowdloanTooSmallContributionMessage(
            value,
            preferredLanguages: locale?.rLanguages
        )

        let title = R.string.localizable.crowdloanTooSmallContributionTitle(
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentCapReachedError(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable.crowdloanCapReachedRaisedMessage(
            preferredLanguages: locale?.rLanguages
        )

        let title = R.string.localizable.crowdloanCapReachedTitle(
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentAmountExceedsCapError(_ amount: String, from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable.crowdloanCapReachedAmountMessage(
            amount, preferredLanguages: locale?.rLanguages
        )
        let title = R.string.localizable.crowdloanCapReachedTitle(
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentCrowdloanEnded(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable.crowdloanEndedTitle(
            preferredLanguages: locale?.rLanguages
        )

        let title = R.string.localizable.crowdloanEndedMessage(
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentCrowdloanPrivateNotSupported(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable.crowdloanPrivateCrowdloanMessage(
            preferredLanguages: locale?.rLanguages
        )

        let title = R.string.localizable.crowdloanPrivateCrowdloanTitle(
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
