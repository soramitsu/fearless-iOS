import FearlessUtils

struct CustomValidatorCellViewModel {
    let icon: DrawableIcon?
    let name: String?
    let address: String
    let details: String?
    let auxDetails: String?
    let shouldShowWarning: Bool
    let shouldShowError: Bool
    var isSelected: Bool = false
}

struct CustomValidatorListViewModel {
    var headerViewModel: TitleWithSubtitleViewModel
    var cellViewModels: [CustomValidatorCellViewModel]
    var selectedValidatorsCount: Int
    var proceedButtonTitle: String?
    var fillRestButtonVisible: Bool
    var fillRestButtonEnabled: Bool
    var clearButtonEnabled: Bool
    var deselectButtonEnabled: Bool
    var deselectedButtonVisible: Bool
    var identityButtonVisible: Bool
    var identityButtonSelected: Bool
    var title: String
}
