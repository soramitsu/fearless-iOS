import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

final class ExportMnemonicViewFactory: ExportMnemonicViewFactoryProtocol {
    static func createViewForAddress(flow: ExportFlow) -> ExportGenericViewProtocol? {
        let accessoryActionTitle = LocalizableResource { locale in
            R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
        }

        let uiFactory = UIFactory()
        let view = ExportGenericViewController(
            uiFactory: uiFactory,
            binder: ExportGenericViewModelBinder(uiFactory: uiFactory),
            mainTitle: accessoryActionTitle,
            accessoryTitle: nil
        )

        let localizationManager = LocalizationManager.shared

        let presenter = ExportMnemonicPresenter(
            flow: flow,
            localizationManager: localizationManager
        )

        let keychain = Keychain()
        let repository = AccountRepositoryFactory.createRepository()

        let interactor = ExportMnemonicInteractor(
            keystore: keychain,
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager
        )
        let wireframe = ExportMnemonicWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        return view
    }
}
