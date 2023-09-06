import SCard

enum ChainAssetListTableSection: Int {
    case active
    case hidden
}

struct ChainAssetListViewModel {
    let sections: [ChainAssetListTableSection]
    let cellsForSections: [ChainAssetListTableSection: [ChainAccountBalanceCellViewModel]]
    let isColdBoot: Bool
    let hiddenSectionState: HiddenSectionState
    let emptyStateIsActive: Bool
    let soraCardItem: SCCardItem?
    let soraCardHidden: Bool
}
