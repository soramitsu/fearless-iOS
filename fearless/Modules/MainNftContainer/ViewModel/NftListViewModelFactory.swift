import Foundation

protocol NftListViewModelFactoryProtocol {
    func buildViewModel(from nfts: [NFT]) -> [NftListCellModel]
}

final class NftListViewModelFactory: NftListViewModelFactoryProtocol {
    func buildViewModel(from nfts: [NFT]) -> [NftListCellModel] {
        nfts.compactMap { nft in

            var imageViewModel: RemoteImageViewModel?
            if let imagePath = nft.metadata?.image, let url = URL(string: imagePath) {
                imageViewModel = RemoteImageViewModel(url: url)
            }

            return NftListCellModel(imageViewModel: imageViewModel, chainNameLabelText: nft.chain.name, nftNameLabelText: nft.tokenName, collectionNameLabelText: nft.metadata?.description)
        }
    }
}
