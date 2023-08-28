import Foundation
import SoraFoundation

final class MainNftContainerPresenter {
    // MARK: Private properties

    private weak var view: MainNftContainerViewInput?
    private let router: MainNftContainerRouterInput
    private let interactor: MainNftContainerInteractorInput
    private let viewModelFactory: NftListViewModelFactoryProtocol

    // MARK: - Constructors

    init(
        interactor: MainNftContainerInteractorInput,
        router: MainNftContainerRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: NftListViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
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
}

// MARK: - MainNftContainerInteractorOutput

extension MainNftContainerPresenter: MainNftContainerInteractorOutput {
    func didReceive(nfts: [NFT]) {
        print("Resulting nfts contains 840919: \(nfts.first(where: { $0.tokenId == "840919" }) != nil)")
        let viewModels = viewModelFactory.buildViewModel(from: nfts)
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
