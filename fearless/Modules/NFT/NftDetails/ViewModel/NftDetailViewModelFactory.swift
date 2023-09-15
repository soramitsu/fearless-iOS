import Foundation
import SSFModels

protocol NftDetailViewModelFactoryProtocol {
    func buildViewModel(with nft: NFT, address: String) -> NftDetailViewModel
}

final class NftDetailViewModelFactory: NftDetailViewModelFactoryProtocol {
    func buildViewModel(with nft: NFT, address: String) -> NftDetailViewModel {
        var imageViewModel: ImageViewModelProtocol?
        if let url = nft.metadata?.imageURL {
            imageViewModel = RemoteImageViewModel(url: url)
        }

        return NftDetailViewModel(
            nftName: nft.metadata?.name,
            nftDescription: nft.metadata?.description,
            collectionName: nft.tokenName,
            owner: address,
            tokenId: nft.tokenId,
            chain: nft.chain.name,
            imageViewModel: imageViewModel
        )
    }
}
