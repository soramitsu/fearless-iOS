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

        guard
            let balanceInfoModule = Self.configureBalanceInfoModule(metaAccount: selectedMetaAccount),
            let assetListModule = Self.configureAssetListModule(metaAccount: selectedMetaAccount)
        else {
            return nil
        }

        let presenter = WalletMainContainerPresenter(
            selectedMetaAccount: selectedMetaAccount,
            viewModelFactory: WalletMainContainerViewModelFactory(),
            interactor: interactor,
            router: router,
            assetListModuleInput: assetListModule.input,
            localizationManager: localizationManager
        )

        let view = WalletMainContainerViewController(
            balanceInfoViewController: balanceInfoModule.view.controller,
            assetListViewController: assetListModule.view.controller,
            nftViewController: UIViewController(),
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
        metaAccount: MetaAccountModel
    ) -> ChainAssetListModuleCreationResult? {
        ChainAssetListAssembly.configureModule(wallet: metaAccount)
    }
}
