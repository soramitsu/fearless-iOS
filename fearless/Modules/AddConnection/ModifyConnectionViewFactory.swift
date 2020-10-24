import Foundation
import SoraFoundation
import RobinHood

final class AddConnectionViewFactory: AddConnectionViewFactoryProtocol {
    static func createView() -> AddConnectionViewProtocol? {
        let facade = UserDataStorageFacade.shared
        let connectionsMapper = ManagedConnectionItemMapper()
        let connectionsRepository = facade.createRepository(filter: nil,
                                                            sortDescriptors: [NSSortDescriptor.connectionsByOrder],
                                                            mapper: AnyCoreDataMapper(connectionsMapper))

        let substrateOperationFactory = SubstrateOperationFactory(logger: Logger.shared)

        let view = AddConnectionViewController(nib: R.nib.addConnectionViewController)
        let presenter = AddConnectionPresenter(localizationManager: LocalizationManager.shared)
        let interactor = AddConnectionInteractor(repository: AnyDataProviderRepository(connectionsRepository),
                                                    operationManager: OperationManagerFacade.sharedManager,
                                                    substrateOperationFactory: substrateOperationFactory)
        let wireframe = AddConnectionWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
