import Foundation
import SoraFoundation

final class ExportRestoreJsonViewFactory: ExportRestoreJsonViewFactoryProtocol {
    static func createView(
        with models: [RestoreJson],
        flow: ExportFlow
    ) -> ExportGenericViewProtocol? {
        let accessoryActionTitle = LocalizableResource { locale in
            R.string.localizable.commonChangePassword(preferredLanguages: locale.rLanguages)
        }

        let mainActionTitle = LocalizableResource { locale in
            R.string.localizable.accountExportAction(preferredLanguages: locale.rLanguages)
        }

        let interactor = ExportRestoreJsonInteractor(
            settings: SelectedWalletSettings.shared,
            wallet: flow.wallet,
            eventCenter: EventCenter.shared
        )

        let uiFactory = UIFactory()
        let view = ExportGenericViewController(
            uiFactory: uiFactory,
            binder: ExportGenericViewModelBinder(uiFactory: uiFactory),
            mainTitle: mainActionTitle,
            accessoryTitle: accessoryActionTitle
        )

        let presenter = ExportRestoreJsonPresenter(
            models: models,
            flow: flow,
            localizationManager: LocalizationManager.shared
        )
        presenter.wireframe = ExportRestoreJsonWireframe()
        presenter.view = view
        presenter.interacror = interactor

        view.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
