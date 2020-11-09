import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

final class ExportMnemonicViewFactory: ExportMnemonicViewFactoryProtocol {
    static func createViewForAddress(_ address: String) -> ExportGenericViewProtocol? {
        let accessoryActionTitle = LocalizableResource { locale in
            R.string.localizable.accountConfirmationTitle(preferredLanguages: locale.rLanguages)
        }

        let uiFactory = UIFactory()
        let view = ExportGenericViewController(uiFactory: uiFactory,
                                               binder: ExportGenericViewModelBinder(uiFactory: uiFactory),
                                               accessoryTitle: accessoryActionTitle)

        let localizationManager = LocalizationManager.shared

        let presenter = ExportMnemonicPresenter(address: address,
                                                localizationManager: localizationManager)

        let keychain = Keychain()
        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let interactor = ExportMnemonicInteractor(keystore: keychain,
                                                  repository: AnyDataProviderRepository(repository),
                                                  operationManager: OperationManagerFacade.sharedManager)
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
