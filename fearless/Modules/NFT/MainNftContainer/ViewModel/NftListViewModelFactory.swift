import Foundation

protocol NftListViewModelFactoryProtocol {
    func buildViewModel(from collections: [NFTCollection]) -> [NftListCellModel]
}

final class NftListViewModelFactory: NftListViewModelFactoryProtocol {
    func buildViewModel(from collections: [NFTCollection]) -> [NftListCellModel] {
        collections.compactMap { collection in
            let nft = collection.nfts?.first
            var imageViewModel: RemoteImageViewModel?
            if let thumbnailPath = nft?.mediaThumbnail, let url = URL(string: thumbnailPath) {
                imageViewModel = RemoteImageViewModel(url: url)
            }

            return NftListCellModel(
                imageViewModel: imageViewModel,
                chainNameLabelText: collection.chain.name,
                nftNameLabelText: nft?.title,
                collectionNameLabelText: collection.name,
                collection: collection
            )
        }
    }
}
