import Foundation

struct NftListCellModel {
    let imageViewModel: ImageViewModelProtocol?
    let chainNameLabelText: String?
    let collection: NFTCollection
    let currentCount: Int?
    let availableCount: Int?
    let locale: Locale
}
