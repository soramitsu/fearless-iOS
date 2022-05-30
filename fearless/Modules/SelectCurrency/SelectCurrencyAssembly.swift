import UIKit
import SoraFoundation
import SoraKeystore
import RobinHood

final class SelectCurrencyAssembly {
    static func configureModule(with wallet: MetaAccountModel) -> SelectCurrencyModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let eventCenter = EventCenter.shared
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let interactor = SelectCurrencyInteractor(
            selectedMetaAccount: wallet,
            repository: accountRepository,
            jsonDataProviderFactory: JsonDataProviderFactory.shared,
            eventCenter: eventCenter,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let router = SelectCurrencyRouter()

        let presenter = SelectCurrencyPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: SelectCurrencyViewModelFactory(),
            localizationManager: localizationManager
        )

        let view = SelectCurrencyViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
