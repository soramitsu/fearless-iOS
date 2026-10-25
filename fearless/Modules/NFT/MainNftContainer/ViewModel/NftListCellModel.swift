import Foundation
import SSFModels

struct NftCollectionIdentity: Hashable {
    let ecosystem: String
    let chainId: ChainModel.Id
    let collectionId: String
}

struct NftListCellModel {
    let identity: NftCollectionIdentity
    let imageViewModel: ImageViewModelProtocol?
    let chainNameLabelText: String?
    let collection: NFTCollection
    let currentCount: Int?
    let availableCount: Int?
    let locale: Locale
}

struct NftNetworkSectionModel {
    let chainId: ChainModel.Id
    let networkTitle: String
    let items: [NftListCellModel]
}
