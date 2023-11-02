import UIKit

protocol NftListViewModelFactoryProtocol {
    func buildViewModel(from collections: [NFTCollection]) -> [NftListCellModel]
}

final class NftListViewModelFactory: NftListViewModelFactoryProtocol {
    func buildViewModel(from collections: [NFTCollection]) -> [NftListCellModel] {
        collections.sorted(by: { collection1, collection2 in
            collection1.displayName ?? "" < collection2.displayName ?? ""
        }).compactMap { collection in
            var imageViewModel: RemoteImageViewModel?
            if let url = collection.displayThumbnailImageUrl {
                imageViewModel = RemoteImageViewModel(url: url)
            }

            return NftListCellModel(
                imageViewModel: imageViewModel,
                chainNameLabelText: collection.chain.name,
                nftNameLabelText: collection.displayName,
                priceLabelAttributedText: nil,
                collection: collection,
                nftCountLabelText: (collection.nfts?.count).map { String($0) }
            )
        }
    }
}
