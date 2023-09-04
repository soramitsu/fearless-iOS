import Foundation
import SSFModels

protocol NftDetailViewModelFactoryProtocol {
    func buildViewModel(with nft: NFT, address: String) -> NftDetailViewModel
}

final class NftDetailViewModelFactory: NftDetailViewModelFactoryProtocol {
    func buildViewModel(with nft: NFT, address: String) -> NftDetailViewModel {
        var imageViewModel: ImageViewModelProtocol?
        if let image = nft.metadata?.image, let url = URL(string: image) {
            imageViewModel = RemoteImageViewModel(url: url)
        }

        return NftDetailViewModel(
            nftName: nft.metadata?.name,
            nftDescription: nft.metadata?.description,
            collectionName: nft.tokenName,
            owner: address,
            creator: nil,
            chain: nft.chain.name,
            imageViewModel: imageViewModel
        )
    }
}
