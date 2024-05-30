import SSFUtils
import Foundation

struct SelectedValidatorCellViewModel {
    let icon: DrawableIcon?
    let name: String?
    let address: String
    let detailsAttributedString: NSAttributedString?
    let detailsAux: String?
    let shouldShowWarning: Bool
    let shouldShowError: Bool
}

struct SelectedValidatorListViewModel {
    var headerViewModel: TitleWithSubtitleViewModel
    var cellViewModels: [SelectedValidatorCellViewModel]
    var limitIsExceeded: Bool
    let selectedValidatorsLimit: Int
}
