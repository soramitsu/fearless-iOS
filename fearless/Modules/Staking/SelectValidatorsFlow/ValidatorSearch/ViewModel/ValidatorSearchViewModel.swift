import FearlessUtils

struct ValidatorSearchCellViewModel {
    let icon: DrawableIcon?
    let name: String?
    let address: String
    let details: String?
    var isSelected: Bool = false
}

struct ValidatorSearchViewModel {
    var headerViewModel: TitleWithSubtitleViewModel?
    var cellViewModels: [ValidatorSearchCellViewModel]
}
