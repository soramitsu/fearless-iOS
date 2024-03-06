import SSFUtils
import UIKit

struct CustomValidatorListSectionViewModel {
    let title: String
    let cells: [CustomValidatorCellViewModel]
    let icon: UIImage
}

struct CustomValidatorCellViewModel {
    let icon: DrawableIcon?
    let name: String?
    let address: String
    let detailsAttributedString: NSAttributedString?
    let auxDetails: String?
    let shouldShowWarning: Bool
    let shouldShowError: Bool
    var isSelected: Bool = false
}

struct CustomValidatorListViewModel {
    var headerViewModel: TitleWithSubtitleViewModel
    var sections: [CustomValidatorListSectionViewModel]
    var selectedValidatorsCount: Int
    var selectedValidatorsLimit: Int?
    var proceedButtonTitle: String?
    var title: String
}
