import Foundation
import SoraFoundation

final class NftDetailsPresenter {
    // MARK: Private properties

    private weak var view: NftDetailsViewInput?
    private let router: NftDetailsRouterInput
    private let interactor: NftDetailsInteractorInput
    private let address: String
    private let viewModelFactory: NftDetailViewModelFactoryProtocol
    private let nft: NFT
    private let wallet: MetaAccountModel

    // MARK: - Constructors

    init(
        interactor: NftDetailsInteractorInput,
        router: NftDetailsRouterInput,
        localizationManager: LocalizationManagerProtocol,
        address: String,
        viewModelFactory: NftDetailViewModelFactoryProtocol,
        nft: NFT,
        wallet: MetaAccountModel
    ) {
        self.interactor = interactor
        self.router = router
        self.address = address
        self.viewModelFactory = viewModelFactory
        self.nft = nft
        self.wallet = wallet
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - NftDetailsViewOutput

extension NftDetailsPresenter: NftDetailsViewOutput {
    func didLoad(view: NftDetailsViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didBackButtonTapped() {
        router.dismiss(view: view)
    }

    func didSendButtonTapped() {
        router.openSend(nft: nft, wallet: wallet, from: view)
    }

    func didTapCopyOwner() {
        router.presentStatus(
            with: CommonCopiedEvent(locale: selectedLocale),
            animated: true
        )
    }

    func didTapCopyTokenId() {
        router.presentStatus(
            with: CommonCopiedEvent(locale: selectedLocale),
            animated: true
        )
    }
}

// MARK: - NftDetailsInteractorOutput

extension NftDetailsPresenter: NftDetailsInteractorOutput {
    func didReceive(nft: NFT) {
        let viewModel = viewModelFactory.buildViewModel(with: nft, address: address)
        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension NftDetailsPresenter: Localizable {
    func applyLocalization() {}
}

extension NftDetailsPresenter: NftDetailsModuleInput {}
