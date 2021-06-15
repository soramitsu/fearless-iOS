import FearlessUtils

struct CustomValidatorCellViewModel {
    let icon: DrawableIcon?
    let name: String?
    let apyPercentage: String?
    var isSelected: Bool = false
}

struct CustomValidatorListViewModel {
    var headerViewModel: TitleWithSubtitleViewModel
    var cellViewModels: [CustomValidatorCellViewModel]
}
