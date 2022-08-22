import UIKit
import SoraFoundation
import RobinHood

final class WalletMainContainerAssembly {
    static func configureModule(selectedMetaAccount: MetaAccountModel) -> WalletMainContainerModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: []
        )

        let interactor = WalletMainContainerInteractor(
            accountRepository: AnyDataProviderRepository(accountRepository),
            chainRepository: AnyDataProviderRepository(chainRepository),
            selectedMetaAccount: selectedMetaAccount,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared
        )

        let router = WalletMainContainerRouter()

        let presenter = WalletMainContainerPresenter(
            selectedMetaAccount: selectedMetaAccount,
            viewModelFactory: WalletMainContainerViewModelFactory(),
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        guard
            let balanceInfoModule = Self.configureBalanceInfoModule(metaAccount: selectedMetaAccount),
            let assetListModule = Self.configureAssetListModule(
                metaAccount: selectedMetaAccount,
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
        metaAccount: MetaAccountModel
    ) -> BalanceInfoModuleCreationResult? {
        BalanceInfoAssembly.configureModule(with: .wallet(metaAccount: metaAccount))
    }

    private static func configureAssetListModule(
        metaAccount: MetaAccountModel,
        delegate: ChainAssetListModuleOutput?
    ) -> ChainAssetListModuleCreationResult? {
        ChainAssetListAssembly.configureModule(wallet: metaAccount, delegate: delegate)
    }

    private static func configureNftModule() -> MainNftContainerModuleCreationResult? {
        MainNftContainerAssembly.configureModule()
    }
}
