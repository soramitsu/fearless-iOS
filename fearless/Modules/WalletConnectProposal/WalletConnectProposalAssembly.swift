import UIKit
import WalletConnectSign
import SoraFoundation
import RobinHood

final class WalletConnectProposalAssembly {
    static func configureModule(
        status: WalletConnectProposalPresenter.SessionStatus
    ) -> WalletConnectProposalModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: []
        )

        let interactor = WalletConnectProposalInteractor(
            walletConnect: WalletConnectServiceImpl.shared,
            walletRepository: AnyDataProviderRepository(accountRepository),
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let router = WalletConnectProposalRouter()

        let walletConnectModelFactory = WalletConnectModelFactoryImpl()
        let viewModelFactory = WalletConnectProposalViewModelFactoryImpl(
            status: status,
            walletConnectModelFactory: walletConnectModelFactory
        )
        let presenter = WalletConnectProposalPresenter(
            status: status,
            walletConnectModelFactory: walletConnectModelFactory,
            viewModelFactory: viewModelFactory,
            logger: Logger.shared,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = WalletConnectProposalViewController(
            status: status,
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
