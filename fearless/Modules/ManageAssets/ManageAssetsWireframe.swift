import Foundation

final class ManageAssetsWireframe: ManageAssetsWireframeProtocol {
    func showImport(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?) {
        guard let importController = AccountImportViewFactory
            .createViewForOnboarding(.chain(model: uniqueChainModel))?.controller
        else {
            return
        }

        view?.controller.navigationController?.pushViewController(importController, animated: true)
    }

    func showCreate(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?) {
        guard let controller = UsernameSetupViewFactory
            .createViewForOnboarding(flow: .chain(model: uniqueChainModel))?.controller
        else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }

    func presentAccountOptions(
        from view: ControllerBackedProtocol?,
        locale: Locale?,
        options: [MissingAccountOption],
        uniqueChainModel: UniqueChainModel,
        skipBlock: @escaping (ChainModel) -> Void
    ) {
        var actions: [SheetAlertPresentableAction] = options.map { option in
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

        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)

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

    func showFilters(
        _ filters: [TitleSwitchTableViewCellModel],
        from view: ControllerBackedProtocol?
    ) {
        guard
            let picker = ModalPickerFactory.createPickerForFilterOptions(
                options: filters
            ) else {
            return
        }

        view?.controller.navigationController?.present(picker, animated: true)
    }

    func showSelectChain(
        chainModels: [ChainModel]?,
        selectedMetaAccount: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        delegate: ChainSelectionDelegate,
        from view: ControllerBackedProtocol?
    ) {
        guard
            let viewController = ChainSelectionViewFactory.createView(
                delegate: delegate,
                selectedChainId: selectedChainId,
                repositoryFilter: nil,
                selectedMetaAccount: selectedMetaAccount,
                includeAllNetworksCell: true,
                showBalances: false,
                chainModels: chainModels,
                assetSelectionType: .normal
            )?.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(viewController, animated: true)
    }
}
