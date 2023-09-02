import Foundation

protocol NftCollectionViewModelFactoryProtocol {
    func buildViewModel(from collection: NFTCollection) -> NftCollectionViewModel
}

final class NftCollectionViewModelFactory: NftCollectionViewModelFactoryProtocol {
    func buildViewModel(from collection: NFTCollection) -> NftCollectionViewModel {
        let cellModels: [NftCollectionCellViewModel] = collection.nfts.compactMap {
            var imageViewModel: RemoteImageViewModel?
            if let image = $0.metadata?.image, let url = URL(string: image) {
                imageViewModel = RemoteImageViewModel(url: url)
            }

            return NftCollectionCellViewModel(
                imageViewModel: imageViewModel,
                name: $0.metadata?.name,
                nft: $0
            )
        }

        return NftCollectionViewModel(collectionName: collection.name, cellModels: cellModels)
    }
}
