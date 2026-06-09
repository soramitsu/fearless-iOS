import UIKit
import FearlessFoundation
import FearlessSecureStorage
import IrohaCrypto
import SSFUtils
import RobinHood
import SSFNetwork

final class ProfileViewFactory: ProfileViewFactoryProtocol {
    // swiftlint:disable:next function_body_length
    static func createView() -> ProfileViewProtocol? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else { return nil }
        let localizationManager = LocalizationManager.shared
        let repository = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
            .createManagedMetaAccountRepository(
                for: nil,
                sortDescriptors: [NSSortDescriptor.accountsByOrder]
            )

        let accountScoreFetcher = NomisAccountStatisticsFetcher(
            networkWorker: NetworkWorkerDefault(),
            signer: NomisRequestSigner()
        )
        let settings = SettingsManager.shared
        let profileViewModelFactory = ProfileViewModelFactory(
            iconGenerator: UniversalIconGenerator(),
            biometry: BiometryAuth(),
            settings: settings,
            accountScoreFetcher: accountScoreFetcher
        )

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let accountInfoFetcher = createAccountInfoFetcher()

        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let walletBalanceSubscriptionAdapter = WalletBalanceSubscriptionAdapter.shared

        let missingAccountHelper = MissingAccountFetcher(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let chainsIssuesCenter = ChainsIssuesCenter(
            wallet: selectedMetaAccount,
            networkIssuesCenter: NetworkIssuesCenter.shared,
            eventCenter: EventCenter.shared,
            missingAccountHelper: missingAccountHelper,
            accountInfoFetcher: accountInfoFetcher
        )

        let walletConnectModelFactory = WalletConnectModelFactoryImpl()
        let walletConnectDisconnectService = WalletConnectDisconnectServiceImpl(
            walletConnectModelFactory: walletConnectModelFactory,
            chainAssetFetcher: chainAssetFetching
        )

        let interactor = ProfileInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            repository: repository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            selectedMetaAccount: selectedMetaAccount,
            walletBalanceSubscriptionAdapter: walletBalanceSubscriptionAdapter,
            walletRepository: accountRepository,
            chainsIssuesCenter: chainsIssuesCenter,
            walletConnectDisconnectService: walletConnectDisconnectService
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
            iconGenerating: UniversalIconGenerator(),
            localizationManager: localizationManager
        )

        return view
    }

    private static func createAccountInfoFetcher() -> AccountInfoFetchingProtocol {
        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()

        return AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: chainRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
