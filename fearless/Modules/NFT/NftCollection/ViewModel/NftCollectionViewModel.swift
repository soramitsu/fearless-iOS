import Foundation

struct NftCollectionViewModel {
    let collectionName: String?
    let collectionImage: ImageViewModelProtocol?
    let collectionDescription: String?
    let ownedCellModels: [NftCellViewModel]
    let availableCellModels: [NftCellViewModel]
}
