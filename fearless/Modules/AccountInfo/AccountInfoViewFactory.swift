import Foundation
import RobinHood
import SoraKeystore
import SoraFoundation
import FearlessUtils

final class AccountInfoViewFactory: AccountInfoViewFactoryProtocol {
    static func createView(address: String) -> AccountInfoViewProtocol? {
        let facade = UserDataStorageFacade.shared
        let mapper = ManagedAccountItemMapper()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let view = AccountInfoViewController(nib: R.nib.accountInfoViewController)
        view.iconGenerating = PolkadotIconGenerator()

        let presenter = AccountInfoPresenter(address: address,
                                             localizationManager: LocalizationManager.shared)
        let interactor = AccountInfoInteractor(repository: AnyDataProviderRepository(repository),
                                               settings: SettingsManager.shared,
                                               keystore: Keychain(),
                                               eventCenter: EventCenter.shared,
                                               operationManager: OperationManagerFacade.sharedManager)
        let wireframe = AccountInfoWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
