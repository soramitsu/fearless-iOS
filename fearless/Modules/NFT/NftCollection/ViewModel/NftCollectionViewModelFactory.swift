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

            let description = "#\(String(describing: $0.tokenId)) in Editions of \(collection.nfts?.count ?? 0)"

            let type: NftType = collection.nfts?.contains($0) == true ? .owned : .available

            return NftCellViewModel(
                imageViewModel: imageViewModel,
                name: $0.displayName,
                description: description,
                type: type,
                nft: $0,
                locale: locale
            )
        } ?? []

        let ownedCellModels = buildCellModels(
            from: collection.nfts ?? [],
            totalCount: collection.nfts?.count ?? 0,
            type: .owned,
            locale: locale
        )

        let availableCellModels = buildCellModels(
            from: collection.availableNfts?.filter { nft in
                collection.nfts?.contains(nft) != true
            } ?? [],
            totalCount: collection.nfts?.count ?? 0,
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
        totalCount: Int,
        type: NftType,
        locale: Locale
    ) -> [NftCellViewModel] {
        nfts.compactMap {
            var imageViewModel: RemoteImageViewModel?
            if let url = $0.thumbnailURL {
                imageViewModel = RemoteImageViewModel(url: url)
            }

            let description = "#\(String(describing: $0.tokenId)) in Editions of \(totalCount)"

            return NftCellViewModel(
                imageViewModel: imageViewModel,
                name: $0.displayName,
                description: description,
                type: type,
                nft: $0,
                locale: locale
            )
        }
    }
}
