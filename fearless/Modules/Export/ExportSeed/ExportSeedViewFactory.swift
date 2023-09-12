import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

final class ExportSeedViewFactory: ExportSeedViewFactoryProtocol {
    static func createViewForAddress(flow: ExportFlow) -> ExportGenericViewProtocol? {
        let uiFactory = UIFactory()
        let view = ExportGenericViewController(
            uiFactory: uiFactory,
            binder: ExportGenericViewModelBinder(uiFactory: uiFactory),
            mainTitle: nil,
            accessoryTitle: nil
        )

        let localizationManager = LocalizationManager.shared

        let presenter = ExportSeedPresenter(
            flow: flow,
            localizationManager: localizationManager
        )

        let keychain = Keychain()
        let repository = AccountRepositoryFactory.createRepository()

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = ExportSeedInteractor(
            keystore: keychain,
            accountRepository: AnyDataProviderRepository(repository),
            operationManager: OperationManagerFacade.sharedManager,
            chainRepository: AnyDataProviderRepository(chainRepository),
            eventCenter: EventCenter.shared
        )
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
