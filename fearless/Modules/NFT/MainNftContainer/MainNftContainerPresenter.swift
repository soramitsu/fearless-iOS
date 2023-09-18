import Foundation
import SoraFoundation

final class MainNftContainerPresenter {
    // MARK: Private properties

    private weak var view: MainNftContainerViewInput?
    private let router: MainNftContainerRouterInput
    private let interactor: MainNftContainerInteractorInput
    private let viewModelFactory: NftListViewModelFactoryProtocol
    private var wallet: MetaAccountModel
    private let eventCenter: EventCenterProtocol

    // MARK: - Constructors

    init(
        interactor: MainNftContainerInteractorInput,
        router: MainNftContainerRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: NftListViewModelFactoryProtocol,
        wallet: MetaAccountModel,
        eventCenter: EventCenterProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.eventCenter = eventCenter
        self.localizationManager = localizationManager

        eventCenter.add(observer: self)
    }

    // MARK: - Private methods

    func updateData() {
        interactor.fetchData()
    }
}

// MARK: - MainNftContainerViewOutput

extension MainNftContainerPresenter: MainNftContainerViewOutput {
    func didLoad(view: MainNftContainerViewInput) {
        self.view = view
        interactor.setup(with: self)
        updateData()
    }

    func didSelect(collection: NFTCollection) {
        guard let address = wallet.fetch(for: collection.chain.accountRequest())?.toAddress() else {
            return
        }

        router.showCollection(collection, wallet: wallet, address: address, from: view)
    }

    func didPullToRefresh() {
        interactor.fetchData()
    }
}

// MARK: - MainNftContainerInteractorOutput

extension MainNftContainerPresenter: MainNftContainerInteractorOutput {
    func didReceive(collections: [NFTCollection]) {
        let viewModels = viewModelFactory.buildViewModel(from: collections)
        view?.didReceive(viewModels: viewModels)
    }
}

// MARK: - Localizable

extension MainNftContainerPresenter: Localizable {
    func applyLocalization() {}
}

extension MainNftContainerPresenter: MainNftContainerModuleInput {}

extension MainNftContainerPresenter: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        wallet = event.account

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceive(viewModels: nil)
        }
        interactor.fetchData()
    }
}
