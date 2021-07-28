import FearlessUtils

struct SelectedValidatorCellViewModel {
    let icon: DrawableIcon?
    let name: String?
    let address: String
    let details: String?
    let shouldShowWarning: Bool
    let shouldShowError: Bool
}

struct SelectedValidatorListViewModel {
    var headerViewModel: TitleWithSubtitleViewModel
    var cellViewModels: [SelectedValidatorCellViewModel]
    var limitIsExceeded: Bool
}
