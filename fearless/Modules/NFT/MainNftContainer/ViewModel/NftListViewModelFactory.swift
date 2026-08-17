import UIKit

protocol NftListViewModelFactoryProtocol {
    func buildViewModel(from collections: [NFTCollection], locale: Locale) -> [NftNetworkSectionModel]
}

final class NftListViewModelFactory: NftListViewModelFactoryProtocol {
    func buildViewModel(from collections: [NFTCollection], locale: Locale) -> [NftNetworkSectionModel] {
        let cells = collections.map { collection in
            var imageViewModel: RemoteImageViewModel?
            if let url = collection.displayThumbnailImageUrl {
                imageViewModel = RemoteImageViewModel(url: url)
            } else if let nftUrl = collection.nfts?.first?.metadata?.imageURL {
                imageViewModel = RemoteImageViewModel(url: nftUrl)
            }

            let currentCount = collection.nfts?.count
            let availableCount = collection.totalSupply.map { Int($0) } ?? nil
            let ecosystem = AssetKey.ecosystem(for: collection.chain)
            let rawCollectionId = collection.address
                ?? collection.nfts?.compactMap(\.smartContract).first
                ?? "missing:" + (collection.nfts?.compactMap(\.tokenId).sorted().joined(separator: ",") ?? "")
            let collectionId = collection.chain.isEthereumBased
                ? rawCollectionId.lowercased()
                : rawCollectionId

            return NftListCellModel(
                identity: NftCollectionIdentity(
                    ecosystem: ecosystem,
                    chainId: collection.chain.chainId,
                    collectionId: collectionId
                ),
                imageViewModel: imageViewModel,
                chainNameLabelText: collection.chain.name,
                collection: collection,
                currentCount: currentCount,
                availableCount: availableCount,
                locale: locale
            )
        }

        return Dictionary(grouping: cells, by: { $0.collection.chain.chainId })
            .map { chainId, items in
                let chain = items[0].collection.chain
                return NftNetworkSectionModel(
                    chainId: chainId,
                    networkTitle: "\(chain.name) · \(AssetKey.ecosystem(for: chain).capitalized)",
                    items: items.sorted {
                        ($0.collection.displayName ?? "", $0.identity.collectionId) <
                            ($1.collection.displayName ?? "", $1.identity.collectionId)
                    }
                )
            }
            .sorted {
                ($0.networkTitle, $0.chainId) < ($1.networkTitle, $1.chainId)
            }
    }
}
