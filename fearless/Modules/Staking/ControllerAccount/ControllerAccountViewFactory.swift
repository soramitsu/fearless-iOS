import Foundation
import SoraFoundation
import SoraKeystore
import FearlessUtils
import RobinHood

struct ControllerAccountViewFactory {
    static func createView() -> ControllerAccountViewProtocol? {
        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager
        )
        let settings = SettingsManager.shared
        let chain = settings.selectedConnection.type.chain
        let networkType = settings.selectedConnection.type
        let facade = UserDataStorageFacade.shared

        let filter = NSPredicate.filterAccountBy(networkType: networkType)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            facade.createRepository(
                filter: filter,
                sortDescriptors: [.accountsByOrder]
            )
        guard let selectedAccount = settings.selectedAccount else {
            return nil
        }

        let interactor = ControllerAccountInteractor(
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            substrateProviderFactory: substrateProviderFactory,
            selectedAccountAddress: selectedAccount.address,
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationManager: OperationManagerFacade.sharedManager
        )
        let wireframe = ControllerAccountWireframe()

        let viewModelFactory = ControllerAccountViewModelFactory(
            selectedAccount: selectedAccount,
            iconGenerator: PolkadotIconGenerator()
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let presenter = ControllerAccountPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            applicationConfig: ApplicationConfig.shared,
            selectedAccount: selectedAccount,
            chain: chain,
            dataValidatingFactory: dataValidatingFactory
        )

        let view = ControllerAccountViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }
}
