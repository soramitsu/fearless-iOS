import Foundation
import SoraFoundation
import Kingfisher

final class NftDetailsPresenter {
    // MARK: Private properties

    private weak var view: NftDetailsViewInput?
    private let router: NftDetailsRouterInput
    private let interactor: NftDetailsInteractorInput
    private let address: String
    private let viewModelFactory: NftDetailViewModelFactoryProtocol
    private let nft: NFT
    private let wallet: MetaAccountModel
    private let type: NftType
    private var viewModel: NftDetailViewModel?

    // MARK: - Constructors

    init(
        interactor: NftDetailsInteractorInput,
        router: NftDetailsRouterInput,
        localizationManager: LocalizationManagerProtocol,
        address: String,
        viewModelFactory: NftDetailViewModelFactoryProtocol,
        nft: NFT,
        wallet: MetaAccountModel,
        type: NftType
    ) {
        self.interactor = interactor
        self.router = router
        self.address = address
        self.viewModelFactory = viewModelFactory
        self.nft = nft
        self.wallet = wallet
        self.type = type

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func prepareShareSources(completion: @escaping ([Any]) -> Void) {
        getNftImage { [weak self] image in
            guard let self = self else { return }
            let addressSource = TextSharingSource(message: R.string.localizable.nftShareAddress(self.address, preferredLanguages: self.selectedLocale.rLanguages))
            var sources: [Any] = [addressSource]

            if let image = image {
                sources.append(image)
            }

            if let collectionTitle = self.viewModel?.collectionName {
                let collectionSource = TextSharingSource(message: R.string.localizable.nftCollectionTitle(preferredLanguages: self.selectedLocale.rLanguages) + ": " + collectionTitle)
                sources.append(collectionSource)
            }

            if let owner = self.viewModel?.owner {
                let ownerSource = TextSharingSource(message: R.string.localizable.nftOwnerTitle(preferredLanguages: self.selectedLocale.rLanguages) + ": " + owner)
                sources.append(ownerSource)
            }

            if let creator = self.viewModel?.creator {
                let creatorSource = TextSharingSource(message: R.string.localizable.nftCreatorTitle(preferredLanguages: self.selectedLocale.rLanguages) + ": " + creator)
                sources.append(creatorSource)
            }

            if let network = self.viewModel?.chain {
                let networkSource = TextSharingSource(message: R.string.localizable.commonNetwork(preferredLanguages: self.selectedLocale.rLanguages) + ": " + network)
                sources.append(networkSource)
            }

            if let tokenId = self.viewModel?.tokenId {
                let tokenIdSource = TextSharingSource(message: R.string.localizable.nftTokenidTitle(preferredLanguages: self.selectedLocale.rLanguages) + ": " + tokenId)
                sources.append(tokenIdSource)
            }

            if let type = self.viewModel?.tokenType {
                let typeSource = TextSharingSource(message: R.string.localizable.stakingAnalyticsDetailsType(preferredLanguages: self.selectedLocale.rLanguages) + ": " + type)
                sources.append(typeSource)
            }
            completion(sources)
        }
    }

    private func getNftImage(completion: @escaping (UIImage?) -> Void) {
        if let urlString = nft.mediaThumbnail, let url = URL(string: urlString) {
            KingfisherManager.shared.retrieveImage(with: url) { result in
                switch result {
                case let .success(imageResult):
                    completion(imageResult.image)
                case .failure:
                    completion(nil)
                }
            }
        } else {
            completion(nil)
        }
    }

    private func provideViewModel(for nft: NFT, owner: String?) {
        let viewModel = viewModelFactory.buildViewModel(
            with: nft,
            nftType: type,
            ownerString: owner
        )
        self.viewModel = viewModel
        view?.didReceive(viewModel: viewModel)
    }
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

    func didTapSendButton() {
        router.openSend(nft: nft, wallet: wallet, from: view)
    }

    func didTapShareButton() {
        prepareShareSources { [weak self] sources in
            self?.router.share(
                sources: sources,
                from: self?.view,
                with: nil
            )
        }
    }

    func didTapCopy() {
        router.presentStatus(
            with: CommonCopiedEvent(locale: selectedLocale),
            animated: true
        )
    }
}

// MARK: - NftDetailsInteractorOutput

extension NftDetailsPresenter: NftDetailsInteractorOutput {
    func didReceive(nft: NFT) {
        provideViewModel(for: nft, owner: nil)
    }

    func didReceive(owners: [String]) {
        let ownerString = viewModelFactory.buildOwnerString(
            owners: owners,
            address: address,
            locale: selectedLocale
        )
        provideViewModel(for: nft, owner: ownerString)
    }
}

// MARK: - Localizable

extension NftDetailsPresenter: Localizable {
    func applyLocalization() {}
}

extension NftDetailsPresenter: NftDetailsModuleInput {}
