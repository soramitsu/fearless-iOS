import UIKit
import SoraFoundation
import RobinHood

final class WalletMainContainerAssembly {
    static func configureModule(wallet: MetaAccountModel) -> WalletMainContainerModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: []
        )

        let missingAccountHelper = MissingAccountsHelper(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let chainsIssuesCenter = ChainsIssuesCenter(
            wallet: wallet,
            networkIssuesCenter: NetworkIssuesCenter.shared,
            eventCenter: EventCenter.shared,
            missingAccountHelper: missingAccountHelper
        )

        let interactor = WalletMainContainerInteractor(
            accountRepository: AnyDataProviderRepository(accountRepository),
            chainRepository: AnyDataProviderRepository(chainRepository),
            wallet: wallet,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            chainsIssuesCenter: chainsIssuesCenter
        )

        let router = WalletMainContainerRouter()

        let presenter = WalletMainContainerPresenter(
            wallet: wallet,
            viewModelFactory: WalletMainContainerViewModelFactory(),
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        guard
            let balanceInfoModule = Self.configureBalanceInfoModule(wallet: wallet),
            let assetListModule = Self.configureAssetListModule(
                wallet: wallet,
                delegate: presenter
            ),
            let nftModule = Self.configureNftModule()
        else {
            return nil
        }

        presenter.assetListModuleInput = assetListModule.input

        let view = WalletMainContainerViewController(
            balanceInfoViewController: balanceInfoModule.view.controller,
            pageControllers: [assetListModule.view.controller, nftModule.view.controller],
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }

    private static func configureBalanceInfoModule(
        wallet: MetaAccountModel
    ) -> BalanceInfoModuleCreationResult? {
        BalanceInfoAssembly.configureModule(with: .wallet(metaAccount: wallet))
    }

    private static func configureAssetListModule(
        wallet: MetaAccountModel,
        delegate: ChainAssetListModuleOutput?
    ) -> ChainAssetListModuleCreationResult? {
        ChainAssetListAssembly.configureModule(wallet: wallet, delegate: delegate)
    }

    private static func configureNftModule() -> MainNftContainerModuleCreationResult? {
        MainNftContainerAssembly.configureModule()
    }
}
