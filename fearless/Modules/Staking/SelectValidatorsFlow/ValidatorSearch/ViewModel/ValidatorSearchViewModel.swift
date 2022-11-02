import FearlessUtils

struct ValidatorSearchCellViewModel {
    let icon: DrawableIcon?
    let name: String?
    let address: String
    let detailsAttributedString: NSAttributedString?
    let detailsAux: String?
    let shouldShowWarning: Bool
    let shouldShowError: Bool
    var isSelected: Bool = false
}

struct ValidatorSearchViewModel {
    var headerViewModel: TitleWithSubtitleViewModel?
    var cellViewModels: [ValidatorSearchCellViewModel]
    var differsFromInitial: Bool = false
}
