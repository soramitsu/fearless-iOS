import Foundation

struct NftListCellModel {
    let imageViewModel: ImageViewModelProtocol?
    let chainNameLabelText: String?
    let nftNameLabelText: String?
    let priceLabelAttributedText: NSAttributedString?
    let collection: NFTCollection
    let nftCountLabelText: String?
}
