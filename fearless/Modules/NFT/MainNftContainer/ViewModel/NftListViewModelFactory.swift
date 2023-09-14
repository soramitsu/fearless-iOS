import Foundation

protocol NftListViewModelFactoryProtocol {
    func buildViewModel(from collections: [NFTCollection]) -> [NftListCellModel]
}

final class NftListViewModelFactory: NftListViewModelFactoryProtocol {
    func buildViewModel(from collections: [NFTCollection]) -> [NftListCellModel] {
        collections.compactMap { collection in
            var imageViewModel: RemoteImageViewModel?
            if let url = collection.imageURL {
                imageViewModel = RemoteImageViewModel(url: url)
            }

            return NftListCellModel(
                imageViewModel: imageViewModel,
                chainNameLabelText: collection.chain.name,
                nftNameLabelText: collection.name,
                collectionNameLabelText: collection.name,
                collection: collection
            )
        }
    }
}
