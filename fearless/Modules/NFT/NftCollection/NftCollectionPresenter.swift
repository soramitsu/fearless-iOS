import Foundation
import SoraFoundation
import SSFModels

final class NftCollectionPresenter {
    // MARK: Private properties

    private weak var view: NftCollectionViewInput?
    private let router: NftCollectionRouterInput
    private let interactor: NftCollectionInteractorInput
    private let viewModelFactory: NftCollectionViewModelFactoryProtocol
    private let address: String
    private let wallet: MetaAccountModel

    // MARK: - Constructors

    init(
        interactor: NftCollectionInteractorInput,
        router: NftCollectionRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: NftCollectionViewModelFactoryProtocol,
        address: String,
        wallet: MetaAccountModel
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.address = address
        self.wallet = wallet
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - NftCollectionViewOutput

extension NftCollectionPresenter: NftCollectionViewOutput {
    func didLoad(view: NftCollectionViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didBackButtonTapped() {
        router.dismiss(view: view)
    }

    func didSelect(nft: NFT) {
        router.openNftDetails(nft: nft, wallet: wallet, address: address, from: view)
    }
}

// MARK: - NftCollectionInteractorOutput

extension NftCollectionPresenter: NftCollectionInteractorOutput {
    func didReceive(collection: NFTCollection) {
        let viewModel = viewModelFactory.buildViewModel(from: collection)
        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension NftCollectionPresenter: Localizable {
    func applyLocalization() {}
}

extension NftCollectionPresenter: NftCollectionModuleInput {}
