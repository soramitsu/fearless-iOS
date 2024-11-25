import UIKit

final class BannerCellViewModelDefault: NSObject {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let image: UIImage
    let dismissable: Bool
    let fullsizeImage: Bool
    let bannerType: Banners
    weak var delegate: BannerCellDelegate?
    
    init(
        title: String,
        subtitle: String,
        buttonTitle: String,
        image: UIImage,
        dismissable: Bool,
        fullsizeImage: Bool,
        bannerType: Banners,
        delegate: BannerCellDelegate?
    ) {
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.image = image
        self.dismissable = dismissable
        self.fullsizeImage = fullsizeImage
        self.bannerType = bannerType
        self.delegate = delegate
    }
}

extension BannerCellViewModelDefault: CollectionViewModel {
    var cellType: UICollectionViewCell.Type { BannerCellDefault.self }
}
