import UIKit

final class WalletDetailsWireframe: WalletDetailsWireframeProtocol {
    func close(_ view: WalletDetailsViewProtocol) {
        view.controller.navigationController?.dismiss(animated: true)
    }

    func presentAcions(
        from view: ControllerBackedProtocol?,
        items: [ChainAction],
        callback: @escaping ModalPickerSelectionCallback
    ) {
        let actionsView = ModalPickerFactory.createPickerForList(
            items,
            callback: callback,
            context: nil
        )

        guard let actionsView = actionsView else {
            return
        }

        view?.controller.navigationController?.present(actionsView, animated: true)
    }

    func showExport(
        for address: String,
        chain: ChainModel,
        options: [ExportOption],
        locale: Locale?,
        from view: ControllerBackedProtocol?
    ) {
        authorize(
            animated: true,
            cancellable: true,
            from: view
        ) { [weak self] success in
            if success {
                self?.performExportPresentation(
                    for: address,
                    chain: chain,
                    options: options,
                    locale: locale,
                    from: view
                )
            }
        }
    }

    func presentNodeSelection(
        from view: ControllerBackedProtocol?,
        chain: ChainModel
    ) {
        guard let controller = NodeSelectionViewFactory.createView(chain: chain)?.controller else {
            return
        }

        view?.controller.present(controller, animated: true)
    }

    func present(
        from view: ControllerBackedProtocol,
        url: URL
    ) {
        let webController = WebViewFactory.createWebViewController(for: url, style: .automatic)
        view.controller.present(
            webController,
            animated: true,
            completion: nil
        )
    }
    
    func presentReplaceOptions(
        from view: ControllerBackedProtocol?,
        items: [ChainAction],
        callback: @escaping ModalPickerSelectionCallback
    ) {
        
    }
}

private extension WalletDetailsWireframe {
    func performExportPresentation(
        for address: String,
        chain: ChainModel,
        options: [ExportOption],
        locale: Locale?,
        from view: ControllerBackedProtocol?
    ) {
        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)

        let actions: [AlertPresentableAction] = options.map { option in
            switch option {
            case .mnemonic:
                let title = R.string.localizable.importMnemonic(preferredLanguages: locale?.rLanguages)
                return AlertPresentableAction(title: title) { [weak self] in
                    self?.showMnemonicExport(for: address, chain: chain, from: view)
                }
            case .keystore:
                let title = R.string.localizable.importRecoveryJson(preferredLanguages: locale?.rLanguages)
                return AlertPresentableAction(title: title) { [weak self] in
                    self?.showKeystoreExport(for: address, chain: chain, from: view)
                }
            case .seed:
                let title = R.string.localizable.importRawSeed(preferredLanguages: locale?.rLanguages)
                return AlertPresentableAction(title: title) { [weak self] in
                    self?.showSeedExport(for: address, chain: chain, from: view)
                }
            }
        }

        let title = R.string.localizable.importSourcePickerTitle(preferredLanguages: locale?.rLanguages)
        let alertViewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: cancelTitle
        )

        present(
            viewModel: alertViewModel,
            style: .actionSheet,
            from: view
        )
    }

    func showMnemonicExport(
        for address: String,
        chain: ChainModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let mnemonicView = ExportMnemonicViewFactory.createViewForAddress(
            address,
            chain: chain
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            mnemonicView.controller,
            animated: true
        )
    }

    func showKeystoreExport(
        for address: String,
        chain: ChainModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let passwordView = AccountExportPasswordViewFactory.createView(
            with: address,
            chain: chain
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            passwordView.controller,
            animated: true
        )
    }

    func showSeedExport(for address: String, chain: ChainModel, from view: ControllerBackedProtocol?) {
        guard let seedView = ExportSeedViewFactory.createViewForAddress(address, chain: chain) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            seedView.controller,
            animated: true
        )
    }
}
