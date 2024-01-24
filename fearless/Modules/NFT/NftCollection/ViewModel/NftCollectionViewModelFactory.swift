import Foundation

protocol NftCollectionViewModelFactoryProtocol {
    func buildViewModel(from collection: NFTCollection, locale: Locale) -> NftCollectionViewModel
}

final class NftCollectionViewModelFactory: NftCollectionViewModelFactoryProtocol {
    func buildViewModel(from collection: NFTCollection, locale: Locale) -> NftCollectionViewModel {
        let cellModels: [NftCellViewModel] = collection.nfts?.compactMap {
            var imageViewModel: RemoteImageViewModel?
            if let url = $0.thumbnailURL {
                imageViewModel = RemoteImageViewModel(url: url)
            }

            let type: NftType = collection.nfts?.contains($0) == true ? .owned : .available

            return NftCellViewModel(
                imageViewModel: imageViewModel,
                name: $0.displayName,
                description: $0.description,
                type: type,
                nft: $0,
                locale: locale
            )
        } ?? []

        let ownedCellModels = buildCellModels(
            from: collection.nfts ?? [],
            type: .owned,
            locale: locale
        )

        let availableCellModels = buildCellModels(
            from: collection.availableNfts?.filter { nft in
                collection.nfts?.contains { $0.tokenId == nft.tokenId } != true
            } ?? [],
            type: .available,
            locale: locale
        )

        var imageViewModel: RemoteImageViewModel?
        if let url = collection.displayThumbnailImageUrl {
            imageViewModel = RemoteImageViewModel(url: url)
        } else if let nftUrl = collection.nfts?.first?.metadata?.imageURL {
            imageViewModel = RemoteImageViewModel(url: nftUrl)
        }

        return NftCollectionViewModel(
            collectionName: collection.displayName,
            collectionImage: imageViewModel,
            collectionDescription: collection.desc,
            ownedCellModels: ownedCellModels,
            availableCellModels: availableCellModels
        )
    }

    private func buildCellModels(
        from nfts: [NFT],
        type: NftType,
        locale: Locale
    ) -> [NftCellViewModel] {
        nfts.compactMap {
            var imageViewModel: RemoteImageViewModel?
            if let url = $0.thumbnailURL {
                imageViewModel = RemoteImageViewModel(url: url)
            }

            return NftCellViewModel(
                imageViewModel: imageViewModel,
                name: $0.displayName,
                description: $0.description,
                type: type,
                nft: $0,
                locale: locale
            )
        }
    }
}
