import Foundation

protocol BaseErrorPresentable {
    func presentAmountTooHigh(from view: ControllerBackedProtocol, locale: Locale?)
    func presentFeeNotReceived(from view: ControllerBackedProtocol, locale: Locale?)
    func presentFeeTooHigh(from view: ControllerBackedProtocol, locale: Locale?)
    func presentExtrinsicFailed(from view: ControllerBackedProtocol, locale: Locale?)

    func presentExistentialDepositWarning(
        existentianDepositValue: String,
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    )
    func presentExistentialDepositError(
        existentianDepositValue: String,
        from view: ControllerBackedProtocol,
        locale: Locale?
    )
}

extension BaseErrorPresentable where Self: SheetAlertPresentable & ErrorPresentable {
    func presentAmountTooHigh(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable
            .commonNotEnoughBalanceMessage(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingErrorInsufficientBalanceTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable
            .commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentFeeNotReceived(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable.feeNotYetLoadedMessage(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.feeNotYetLoadedTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentExtrinsicFailed(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable.commonTransactionFailed(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentFeeTooHigh(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable
            .commonNotEnoughFeeMessage(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.stakingErrorInsufficientBalanceTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentExistentialDepositWarning(
        existentianDepositValue: String,
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string.localizable
            .commonExistentialWarningTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .commonExistentialWarningMessage(existentianDepositValue, preferredLanguages: locale?.rLanguages)

        presentWarning(
            for: title,
            message: message,
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentExistentialDepositError(
        existentianDepositValue: String,
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string.localizable
            .commonExistentialWarningTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .commonExistentialWarningMessage(existentianDepositValue, preferredLanguages: locale?.rLanguages)

        presentError(for: title, message: message, view: view, locale: locale)
    }

    func presentWarning(
        for title: String,
        message: String,
        action: @escaping () -> Void,
        view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let proceedTitle = R.string.localizable
            .commonProceed(preferredLanguages: locale?.rLanguages)
        let proceedAction = SheetAlertPresentableAction(title: proceedTitle, style: .pinkBackgroundWhiteText) {
            action()
        }

        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)

        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [proceedAction],
            closeAction: closeTitle,
            icon: R.image.iconWarningBig()
        )

        present(
            viewModel: viewModel,
            from: view
        )
    }

    func presentError(
        for title: String,
        message: String,
        view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)

        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeTitle,
            icon: R.image.iconWarningBig()
        )

        present(
            viewModel: viewModel,
            from: view
        )
    }
}
