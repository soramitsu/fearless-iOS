import UIKit
import WalletConnectSign
import SoraFoundation
import RobinHood

final class WalletConnectProposalAssembly {
    static func configureModule(
        proposal: Session.Proposal
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
            walletConnectModelFactory: walletConnectModelFactory
        )
        let presenter = WalletConnectProposalPresenter(
            proposal: proposal,
            walletConnectModelFactory: walletConnectModelFactory,
            viewModelFactory: viewModelFactory,
            logger: Logger.shared,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = WalletConnectProposalViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
