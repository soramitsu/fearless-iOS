import FearlessUtils

struct CustomValidatorCellViewModel {
    let icon: DrawableIcon?
    let name: String?
    let address: String
    let details: String?
    let auxDetails: String?
    var isSelected: Bool = false
}

struct CustomValidatorListViewModel {
    var headerViewModel: TitleWithSubtitleViewModel
    var cellViewModels: [CustomValidatorCellViewModel]
    var selectedValidatorsCount: Int
}
