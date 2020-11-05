import Foundation

final class AccountInfoWireframe: AccountInfoWireframeProtocol, AuthorizationPresentable {
    func close(view: AccountInfoViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func showExport(for address: String,
                    options: [ExportOption],
                    locale: Locale?,
                    from view: AccountInfoViewProtocol?) {
        authorize(animated: true, cancellable: true) { [weak self] (success) in
            if success {
                self?.performExportPresentation(for: address,
                                                options: options,
                                                locale: locale,
                                                from: view)
            }
        }
    }

    // MARK: Private

    private func performExportPresentation(for address: String,
                                           options: [ExportOption],
                                           locale: Locale?,
                                           from view: AccountInfoViewProtocol?) {
        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)

        let actions: [AlertPresentableAction] = options.map { option in
            switch option {
            case .mnemonic:
                let title = R.string.localizable.importMnemonic(preferredLanguages: locale?.rLanguages)
                return AlertPresentableAction(title: title) { [weak self] in
                    self?.showMnemonicExport(for: address, from: view)
                }
            case .keystore:
                let title = R.string.localizable.importRecoveryJson(preferredLanguages: locale?.rLanguages)
                return AlertPresentableAction(title: title) { [weak self] in
                    self?.showKeystoreExport(for: address, from: view)
                }
            }
        }

        let title = R.string.localizable.importSourcePickerTitle(preferredLanguages: locale?.rLanguages)
        let alertViewModel = AlertPresentableViewModel(title: title,
                                                       message: nil,
                                                       actions: actions,
                                                       closeAction: cancelTitle)

        present(viewModel: alertViewModel,
                style: .actionSheet,
                from: view)
    }

    private func showMnemonicExport(for address: String, from view: AccountInfoViewProtocol?) {

    }

    private func showKeystoreExport(for address: String, from view: AccountInfoViewProtocol?) {
        guard let passwordView = AccountExportPasswordViewFactory.createView(with: address) else {
            return
        }

        view?.controller.navigationController?.pushViewController(passwordView.controller,
                                                                  animated: true)
    }
}
