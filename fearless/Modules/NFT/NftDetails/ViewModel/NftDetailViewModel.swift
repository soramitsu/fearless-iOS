import Foundation

struct NftDetailViewModel {
    let nftName: String?
    let nftDescription: String?
    let collectionName: String?
    let owner: String?
    let tokenId: String?
    let chain: String?
    let imageViewModel: ImageViewModelProtocol?
    let nft: NFT
    let tokenType: String?
    let nftType: NftType
    let creator: String?
    let priceString: String?
}
