import UIKit
import SoraFoundation
import SoraKeystore
import IrohaCrypto
import FearlessUtils

final class ProfileViewFactory: ProfileViewFactoryProtocol {
    static func createView() -> ProfileViewProtocol? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else { return nil }
        let localizationManager = LocalizationManager.shared
        let repository = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
            .createManagedMetaAccountRepository(
                for: nil,
                sortDescriptors: [NSSortDescriptor.accountsByOrder]
            )
        let settings = SettingsManager.shared
        let profileViewModelFactory = ProfileViewModelFactory(
            iconGenerator: PolkadotIconGenerator(),
            biometry: BiometryAuth(),
            settings: settings
        )

        let interactor = ProfileInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            repository: repository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            selectedMetaAccount: selectedMetaAccount
        )

        let presenter = ProfilePresenter(
            viewModelFactory: profileViewModelFactory,
            interactor: interactor,
            wireframe: ProfileWireframe(),
            logger: Logger.shared,
            settings: settings,
            eventCentr: EventCenter.shared,
            localizationManager: localizationManager
        )

        let view = ProfileViewController(
            presenter: presenter,
            iconGenerating: PolkadotIconGenerator(),
            localizationManager: localizationManager
        )

        return view
    }
}
