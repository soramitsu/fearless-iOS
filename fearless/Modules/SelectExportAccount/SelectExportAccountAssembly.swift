import UIKit
import SoraFoundation
import RobinHood

final class SelectExportAccountAssembly {
    static func configureModule(metaAccount: MetaAccountModel) -> SelectExportAccountModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = SelectExportAccountInteractor(
            chainRepository: AnyDataProviderRepository(chainRepository),
            metaAccount: metaAccount,
            operationManager: OperationManagerFacade.sharedManager
        )

        let router = SelectExportAccountRouter()

        let viewModelFactory: SelectExportAccountViewModelFactoryProtocol = SelectExportAccountViewModelFactory()

        let presenter = SelectExportAccountPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: viewModelFactory,
            metaAccount: metaAccount
        )

        let view = SelectExportAccountViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
