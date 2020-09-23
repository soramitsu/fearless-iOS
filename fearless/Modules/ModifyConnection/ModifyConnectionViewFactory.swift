import Foundation
import SoraFoundation
import RobinHood

final class ModifyConnectionViewFactory: ModifyConnectionViewFactoryProtocol {
    static func createView() -> ModifyConnectionViewProtocol? {
        let facade = UserDataStorageFacade.shared
        let connectionsMapper = ManagedConnectionItemMapper()
        let connectionsRepository = facade.createRepository(filter: nil,
                                                            sortDescriptors: [NSSortDescriptor.connectionsByOrder],
                                                            mapper: AnyCoreDataMapper(connectionsMapper))

        let substrateOperationFactory = SubstrateOperationFactory(logger: Logger.shared)

        let view = ModifyConnectionViewController(nib: R.nib.modifyConnectionViewController)
        let presenter = ModifyConnectionPresenter(localizationManager: LocalizationManager.shared)
        let interactor = ModifyConnectionInteractor(repository: AnyDataProviderRepository(connectionsRepository),
                                                    operationManager: OperationManagerFacade.sharedManager,
                                                    substrateOperationFactory: substrateOperationFactory)
        let wireframe = ModifyConnectionWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
