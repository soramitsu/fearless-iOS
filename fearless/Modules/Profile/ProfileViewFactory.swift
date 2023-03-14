import UIKit
import SoraFoundation
import SoraKeystore
import IrohaCrypto
import FearlessUtils
import RobinHood

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

        let eventCenter = EventCenter.shared
        let logger = Logger.shared

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let walletBalanceSubscriptionAdapter = WalletBalanceSubscriptionAdapter(
            metaAccountRepository: AnyDataProviderRepository(accountRepository),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: eventCenter,
            logger: logger
        )

        let interactor = ProfileInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            repository: repository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            selectedMetaAccount: selectedMetaAccount,
            walletBalanceSubscriptionAdapter: walletBalanceSubscriptionAdapter
        )

        let presenter = ProfilePresenter(
            viewModelFactory: profileViewModelFactory,
            interactor: interactor,
            wireframe: ProfileWireframe(),
            logger: Logger.shared,
            settings: settings,
            eventCenter: EventCenter.shared,
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
