import Foundation
import SSFModels
import BigInt

protocol NftDetailViewModelFactoryProtocol {
    func buildViewModel(with nft: NFT, nftType: NftType, ownerString: String?) -> NftDetailViewModel
    func buildOwnerString(owners: [String], address: String, locale: Locale) -> String?
}

final class NftDetailViewModelFactory: NftDetailViewModelFactoryProtocol {
    func buildViewModel(with nft: NFT, nftType: NftType, ownerString: String?) -> NftDetailViewModel {
        var imageViewModel: ImageViewModelProtocol?
        if let url = nft.thumbnailURL {
            imageViewModel = RemoteImageViewModel(url: url)
        }
        let tokenId = nft.tokenId.map { tokenId in
            (try? Data(hexStringSSF: tokenId)).map { "\(BigUInt($0))" }
        }

        return NftDetailViewModel(
            nftName: nft.displayName,
            nftDescription: nft.displayDescription,
            collectionName: nft.collection?.displayName,
            owner: ownerString,
            tokenId: tokenId ?? "",
            chain: nft.chain.name,
            imageViewModel: imageViewModel,
            nft: nft,
            tokenType: nft.tokenType?.rawValue,
            nftType: nftType,
            creator: nft.collection?.creator,
            priceString: nil,
            isScam: nft.collection?.isSpam ?? false
        )
    }

    func buildOwnerString(owners: [String], address: String, locale: Locale) -> String? {
        var ownerString = owners.first { ownerAddress in
            ownerAddress == address
        } ?? owners.first
        if let owner = ownerString, owners.count > 1 {
            ownerString = R.string.localizable.commonAndOthersPlaceholder(
                owner,
                preferredLanguages: locale.rLanguages
            )
        }
        return ownerString ?? ""
    }
}
