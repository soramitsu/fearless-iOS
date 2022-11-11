import UIKit

final class WalletDetailsWireframe: WalletDetailsWireframeProtocol {
    func close(_ view: WalletDetailsViewProtocol) {
        if view.controller.presentingViewController != nil {
            if let navigationController = view.controller.navigationController {
                navigationController.dismiss(animated: true)
            } else {
                view.controller.dismiss(animated: true)
            }
        } else {
            view.controller.navigationController?.popViewController(animated: true)
        }
    }

    func presentActions(
        from view: ControllerBackedProtocol?,
        items: [ChainAction],
        chain: ChainModel,
        callback: @escaping ModalPickerSelectionCallback
    ) {
        let actionsView = ModalPickerFactory.createPickerForList(
            title: chain.name,
            items,
            callback: callback,
            context: nil
        )

        guard let actionsView = actionsView else {
            return
        }

        view?.controller.present(actionsView, animated: true)
    }

    func showExport(
        flow: ExportFlow,
        options: [ExportOption],
        locale: Locale?,
        from view: ControllerBackedProtocol?
    ) {
        performExportPresentation(
            flow: flow,
            options: options,
            locale: locale,
            from: view
        )
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

    func showUniqueChainSourceSelection(
        from view: ControllerBackedProtocol?,
        items: [ReplaceChainOption],
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

        view?.controller.present(actionsView, animated: true)
    }

    func showCreate(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?) {
        guard let controller = UsernameSetupViewFactory.createViewForOnboarding(
            flow: .chain(model: uniqueChainModel)
        )?.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }

    func showImport(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?) {
        guard let importController = AccountImportViewFactory.createViewForOnboarding(
            .chain(model: uniqueChainModel)
        )?.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(importController, animated: true)
    }

    func presentAccountOptions(
        from view: ControllerBackedProtocol?,
        locale: Locale?,
        options: [MissingAccountOption],
        uniqueChainModel: UniqueChainModel,
        skipBlock: @escaping (ChainModel) -> Void
    ) {
        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)

        let actions: [SheetAlertPresentableAction] = options.map { option in
            switch option {
            case .create:
                let title = R.string.localizable.createNewAccount(preferredLanguages: locale?.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.showCreate(uniqueChainModel: uniqueChainModel, from: view)
                }
            case .import:
                let title = R.string.localizable.alreadyHaveAccount(preferredLanguages: locale?.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.showImport(uniqueChainModel: uniqueChainModel, from: view)
                }
            case .skip:
                let title = R.string.localizable.missingAccountSkip(preferredLanguages: locale?.rLanguages)
                return SheetAlertPresentableAction(title: title) {
                    skipBlock(uniqueChainModel.chain)
                }
            }
        }

        let title = R.string.localizable.importSourcePickerTitle(preferredLanguages: locale?.rLanguages)
        let alertViewModel = SheetAlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: cancelTitle
        )

        present(
            viewModel: alertViewModel,
            from: view
        )
    }
}

private extension WalletDetailsWireframe {
    func performExportPresentation(
        flow: ExportFlow,
        options: [ExportOption],
        locale: Locale?,
        from view: ControllerBackedProtocol?
    ) {
        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)

        let actions: [SheetAlertPresentableAction] = options.map { option in
            switch option {
            case .mnemonic:
                let title = R.string.localizable.importMnemonic(preferredLanguages: locale?.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.authorize(
                        animated: true,
                        cancellable: true,
                        from: view
                    ) { [weak self] success in
                        if success {
                            self?.showMnemonicExport(flow: flow, from: view)
                        }
                    }
                }
            case .keystore:
                let title = R.string.localizable.importRecoveryJson(preferredLanguages: locale?.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.authorize(
                        animated: true,
                        cancellable: true,
                        from: view
                    ) { [weak self] success in
                        if success {
                            self?.showKeystoreExport(flow: flow, from: view)
                        }
                    }
                }
            case .seed:
                let title = R.string.localizable.importRawSeed(preferredLanguages: locale?.rLanguages)
                return SheetAlertPresentableAction(title: title) { [weak self] in
                    self?.authorize(
                        animated: true,
                        cancellable: true,
                        from: view
                    ) { [weak self] success in
                        if success {
                            self?.showSeedExport(flow: flow, from: view)
                        }
                    }
                }
            }
        }

        let title = R.string.localizable.importSourcePickerTitle(preferredLanguages: locale?.rLanguages)
        let alertViewModel = SheetAlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: cancelTitle
        )

        present(
            viewModel: alertViewModel,
            from: view
        )
    }

    func showMnemonicExport(
        flow: ExportFlow,
        from view: ControllerBackedProtocol?
    ) {
        guard let mnemonicView = ExportMnemonicViewFactory.createViewForAddress(
            flow: flow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            mnemonicView.controller,
            animated: true
        )
    }

    func showKeystoreExport(
        flow: ExportFlow,
        from view: ControllerBackedProtocol?
    ) {
        guard let passwordView = AccountExportPasswordViewFactory.createView(
            flow: flow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            passwordView.controller,
            animated: true
        )
    }

    func showSeedExport(
        flow: ExportFlow,
        from view: ControllerBackedProtocol?
    ) {
        guard let seedView = ExportSeedViewFactory.createViewForAddress(flow: flow) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            seedView.controller,
            animated: true
        )
    }
}
