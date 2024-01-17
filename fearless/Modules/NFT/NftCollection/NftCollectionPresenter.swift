import Foundation
import SoraFoundation
import SSFModels
import Kingfisher
import BigInt

final class NftCollectionPresenter {
    // MARK: Private properties

    private weak var view: NftCollectionViewInput?
    private let router: NftCollectionRouterInput
    private let interactor: NftCollectionInteractorInput
    private let viewModelFactory: NftCollectionViewModelFactoryProtocol
    private let address: String
    private let wallet: MetaAccountModel

    private var collection: NFTCollection?

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

    private func prepareShareSources(nft: NFT, completion: @escaping ([Any]) -> Void) {
        getNftImage(nft: nft) { [weak self] image in
            guard let self = self else { return }
            let addressSource = TextSharingSource(message: R.string.localizable.nftShareAddress(self.address, preferredLanguages: self.selectedLocale.rLanguages))
            var sources: [Any] = [addressSource]

            if let image = image {
                sources.append(image)
            }

            if let collectionTitle = nft.collection?.displayName {
                let collectionSource = TextSharingSource(message: R.string.localizable.nftCollectionTitle(preferredLanguages: self.selectedLocale.rLanguages) + ": " + collectionTitle)
                sources.append(collectionSource)
            }

            let ownerSource = TextSharingSource(message: R.string.localizable.nftOwnerTitle(preferredLanguages: self.selectedLocale.rLanguages) + ": " + self.address)
            sources.append(ownerSource)

            if let creator = nft.collection?.creator {
                let creatorSource = TextSharingSource(message: R.string.localizable.nftCreatorTitle(preferredLanguages: self.selectedLocale.rLanguages) + ": " + creator)
                sources.append(creatorSource)
            }

            let networkSource = TextSharingSource(message: R.string.localizable.commonNetwork(preferredLanguages: self.selectedLocale.rLanguages) + ": " + nft.chain.name)
            sources.append(networkSource)

            if let tokenId = nft.tokenId.map({ tokenId in
                (try? Data(hexStringSSF: tokenId)).map { "\(BigUInt($0))" }
            }) {
                if let id = tokenId {
                    let tokenIdSource = TextSharingSource(message: R.string.localizable.nftTokenidTitle(preferredLanguages: self.selectedLocale.rLanguages) + ": " + id)
                    sources.append(tokenIdSource)
                }
            }

            if let type = nft.tokenType?.rawValue {
                let typeSource = TextSharingSource(message: R.string.localizable.stakingAnalyticsDetailsType(preferredLanguages: self.selectedLocale.rLanguages) + ": " + type)
                sources.append(typeSource)
            }
            completion(sources)
        }
    }

    private func getNftImage(nft: NFT, _ completion: @escaping (UIImage?) -> Void) {
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
}

// MARK: - NftCollectionViewOutput

extension NftCollectionPresenter: NftCollectionViewOutput {
    func didLoad(view: NftCollectionViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func viewAppeared() {
        interactor.initialSetup()
    }

    func didBackButtonTapped() {
        router.dismiss(view: view)
    }

    func didSelect(nft: NFT, type: NftType) {
        router.openNftDetails(nft: nft, type: type, wallet: wallet, address: address, from: view)
    }

    func loadNext() {
        interactor.fetchData(lastId: collection?.availableNfts?.last?.tokenId)
    }
}

// MARK: - NftCollectionInteractorOutput

extension NftCollectionPresenter: NftCollectionInteractorOutput {
    func didReceive(collection: NFTCollection) {
        self.collection = collection
        let viewModel = viewModelFactory.buildViewModel(from: collection, locale: selectedLocale)
        view?.didReceive(viewModel: viewModel)
    }

    func didTapActionButton(nft: NFT, type: NftType) {
        switch type {
        case .owned:
            router.openSend(nft: nft, wallet: wallet, from: view)
        case .available:
            prepareShareSources(nft: nft) { [weak self] sources in
                self?.router.share(
                    sources: sources,
                    from: self?.view,
                    with: nil
                )
            }
        }
    }
}

// MARK: - Localizable

extension NftCollectionPresenter: Localizable {
    func applyLocalization() {}
}

extension NftCollectionPresenter: NftCollectionModuleInput {}
