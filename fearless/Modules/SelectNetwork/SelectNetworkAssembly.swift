import UIKit
import SoraFoundation
import RobinHood
import SoraUI

enum SelectNetworkAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        includingAllNetworks: Bool = true,
        searchTextsViewModel: SelectNetworkSearchViewModel?,
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
            searchTextsViewModel: searchTextsViewModel,
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

enum SelectNetworkSearchViewModel {
    case searchNetworkPlaceholder

    var placeholder: LocalizableResource<String> {
        LocalizableResource<String> { locale in
            switch self {
            case .searchNetworkPlaceholder:
                return R.string.localizable
                    .selectNetworkSearchPlaceholder(preferredLanguages: locale.rLanguages)
            }
        }
    }

    var emptyViewTitle: LocalizableResource<String> {
        LocalizableResource<String> { locale in
            switch self {
            case .searchNetworkPlaceholder:
                return R.string.localizable
                    .emptyViewTitle(preferredLanguages: locale.rLanguages)
            }
        }
    }

    var emptyViewDescription: LocalizableResource<String> {
        LocalizableResource<String> { locale in
            switch self {
            case .searchNetworkPlaceholder:
                return R.string.localizable
                    .selectNetworkSearchEmptySubtitle(preferredLanguages: locale.rLanguages)
            }
        }
    }
}
