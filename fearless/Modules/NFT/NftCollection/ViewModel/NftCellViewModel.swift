import Foundation

enum NftType {
    case owned
    case available
}

struct NftCellViewModel {
    let imageViewModel: RemoteImageViewModel?
    let name: String?
    let description: String?
    let type: NftType
    let nft: NFT
    let locale: Locale
}
