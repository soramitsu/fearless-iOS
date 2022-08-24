import UIKit
import SoraFoundation
import SoraKeystore
import RobinHood
import SoraUI

final class SelectCurrencyAssembly {
    static func configureModule(
        with wallet: MetaAccountModel,
        isModal: Bool
    ) -> SelectCurrencyModuleCreationResult? {
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
        let router = SelectCurrencyRouter(viewIsModal: isModal)

        let presenter = SelectCurrencyPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: SelectCurrencyViewModelFactory(),
            localizationManager: localizationManager
        )

        let view = SelectCurrencyViewController(
            isModal: isModal,
            output: presenter,
            localizationManager: localizationManager
        )

        if isModal {
            view.modalPresentationStyle = .custom

            let factory = ModalSheetBlurPresentationFactory(
                configuration: ModalSheetPresentationConfiguration.fearlessBlur
            )
            view.modalTransitioningFactory = factory
        }

        return (view, presenter)
    }
}
