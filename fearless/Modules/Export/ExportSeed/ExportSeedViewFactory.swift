import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

final class ExportSeedViewFactory: ExportSeedViewFactoryProtocol {
    static func createViewForAddress(_ address: String) -> ExportGenericViewProtocol? {
        let uiFactory = UIFactory()
        let view = ExportGenericViewController(uiFactory: uiFactory,
                                               binder: ExportGenericViewModelBinder(uiFactory: uiFactory),
                                               mainTitle: nil,
                                               accessoryTitle: nil)

        let localizationManager = LocalizationManager.shared

        let presenter = ExportSeedPresenter(address: address,
                                            localizationManager: localizationManager)

        let keychain = Keychain()
        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let interactor = ExportSeedInteractor(keystore: keychain,
                                              repository: AnyDataProviderRepository(repository),
                                              operationManager: OperationManagerFacade.sharedManager)
        let wireframe = ExportSeedWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        return view
    }
}
