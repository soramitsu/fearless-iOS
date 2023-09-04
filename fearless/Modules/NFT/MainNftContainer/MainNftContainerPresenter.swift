import Foundation
import SoraFoundation

final class MainNftContainerPresenter {
    // MARK: Private properties

    private weak var view: MainNftContainerViewInput?
    private let router: MainNftContainerRouterInput
    private let interactor: MainNftContainerInteractorInput
    private let viewModelFactory: NftListViewModelFactoryProtocol
    private let wallet: MetaAccountModel

    // MARK: - Constructors

    init(
        interactor: MainNftContainerInteractorInput,
        router: MainNftContainerRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: NftListViewModelFactoryProtocol,
        wallet: MetaAccountModel
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - MainNftContainerViewOutput

extension MainNftContainerPresenter: MainNftContainerViewOutput {
    func didLoad(view: MainNftContainerViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didSelect(collection: NFTCollection) {
        guard let address = wallet.fetch(for: collection.chain.accountRequest())?.toAddress() else {
            return
        }

        router.showCollection(collection, wallet: wallet, address: address, from: view)
    }
}

// MARK: - MainNftContainerInteractorOutput

extension MainNftContainerPresenter: MainNftContainerInteractorOutput {
    func didReceive(collections: [NFTCollection]) {
        let viewModels = viewModelFactory.buildViewModel(from: collections)
        view?.didReceive(viewModels: viewModels)
    }

    func didReceive(history: [NFTHistoryObject]) {
        view?.didReceive(history: history)
    }
}

// MARK: - Localizable

extension MainNftContainerPresenter: Localizable {
    func applyLocalization() {}
}

extension MainNftContainerPresenter: MainNftContainerModuleInput {}
