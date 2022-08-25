import UIKit
import SoraFoundation
import RobinHood
import SoraUI

final class SelectNetworkAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        includingAllNetworks: Bool = true,
        delegate: SelectNetworkDelegate?
    ) -> SelectNetworkModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let repository = ChainRepositoryFactory().createRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = SelectNetworkInteractor(
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            chainModels: chainModels
        )
        let router = SelectNetworkRouter(delegate: delegate)

        let viewModelFactory = SelectNetworkViewModelFactory()
        let presenter = SelectNetworkPresenter(
            viewModelFactory: viewModelFactory,
            selectedMetaAccount: wallet,
            selectedChainId: selectedChainId,
            includingAllNetworks: includingAllNetworks,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = SelectNetworkViewController(
            output: presenter,
            localizationManager: localizationManager
        )
        view.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        view.modalTransitioningFactory = factory

        return (view, presenter)
    }
}
