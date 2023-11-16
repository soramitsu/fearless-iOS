import UIKit

protocol NftListViewModelFactoryProtocol {
    func buildViewModel(from collections: [NFTCollection], locale: Locale) -> [NftListCellModel]
}

final class NftListViewModelFactory: NftListViewModelFactoryProtocol {
    func buildViewModel(from collections: [NFTCollection], locale: Locale) -> [NftListCellModel] {
        collections.sorted(by: { collection1, collection2 in
            collection1.displayName ?? "" < collection2.displayName ?? ""
        }).compactMap { collection in
            var imageViewModel: RemoteImageViewModel?
            if let url = collection.displayThumbnailImageUrl {
                imageViewModel = RemoteImageViewModel(url: url)
            } else if let nftUrl = collection.nfts?.first?.metadata?.imageURL {
                imageViewModel = RemoteImageViewModel(url: nftUrl)
            }

            let currentCount = collection.nfts?.count ?? 0
            let availableCount = collection.availableNfts?.count ?? 0

            return NftListCellModel(
                imageViewModel: imageViewModel,
                chainNameLabelText: collection.chain.name,
                collection: collection,
                currentCount: currentCount,
                availableCount: availableCount,
                locale: locale
            )
        }
    }
}
