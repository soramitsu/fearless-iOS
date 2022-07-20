import SoraFoundation

struct ValidatorListFilterViewModel {
    let filterModel: ValidatorListFilterViewModelSection?
    let sortModel: ValidatorListFilterViewModelSection
    let canApply: Bool
    let canReset: Bool
}

struct ValidatorListFilterViewModelSection {
    let title: String
    let cellViewModels: [SelectableViewModel<TitleWithSubtitleViewModel>]
}

struct ValidatorListFilterCellViewModel {
    let title: String
    let subtitle: String?
    let isSelected: Bool
}
