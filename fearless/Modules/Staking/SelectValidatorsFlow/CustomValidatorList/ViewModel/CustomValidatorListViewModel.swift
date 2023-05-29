import SSFUtils

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
    var cellViewModels: [CustomValidatorCellViewModel]
    var selectedValidatorsCount: Int
    var selectedValidatorsLimit: Int?
    var proceedButtonTitle: String?
    var title: String
}
