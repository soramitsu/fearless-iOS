import Foundation
import SSFModels
import BigInt

protocol NftDetailViewModelFactoryProtocol {
    func buildViewModel(with nft: NFT, address: String) -> NftDetailViewModel
}

final class NftDetailViewModelFactory: NftDetailViewModelFactoryProtocol {
    func buildViewModel(with nft: NFT, address: String) -> NftDetailViewModel {
        var imageViewModel: ImageViewModelProtocol?
        if let url = nft.metadata?.imageURL {
            imageViewModel = RemoteImageViewModel(url: url)
        }
        let tokenId = nft.tokenId.map { tokenId in
            (try? Data(hexStringSSF: tokenId)).map { "\(BigUInt($0))" }
        }

        return NftDetailViewModel(
            nftName: nft.displayName,
            nftDescription: nft.displayDescription,
            collectionName: nft.collection?.displayName,
            owner: address,
            tokenId: tokenId ?? "",
            chain: nft.chain.name,
            imageViewModel: imageViewModel,
            nft: nft,
            tokenType: nft.tokenType?.rawValue
        )
    }
}
