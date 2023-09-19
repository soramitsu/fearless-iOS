import Foundation

protocol NftCollectionViewModelFactoryProtocol {
    func buildViewModel(from collection: NFTCollection) -> NftCollectionViewModel
}

final class NftCollectionViewModelFactory: NftCollectionViewModelFactoryProtocol {
    func buildViewModel(from collection: NFTCollection) -> NftCollectionViewModel {
        let cellModels: [NftCollectionCellViewModel] = collection.nfts?.compactMap {
            var imageViewModel: RemoteImageViewModel?
            if let url = $0.thumbnailURL {
                imageViewModel = RemoteImageViewModel(url: url)
            }

            return NftCollectionCellViewModel(
                imageViewModel: imageViewModel,
                name: $0.displayName,
                nft: $0
            )
        } ?? []

        return NftCollectionViewModel(collectionName: collection.displayName, cellModels: cellModels)
    }
}
