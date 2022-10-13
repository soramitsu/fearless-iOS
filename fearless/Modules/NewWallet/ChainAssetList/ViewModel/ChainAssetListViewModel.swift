enum ChainAssetListTableSection: Int {
    case active
    case hidden
}

struct ChainAssetListViewModel {
    let sections: [ChainAssetListTableSection]
    let cellsForSections: [ChainAssetListTableSection: [ChainAccountBalanceCellViewModel]]
    let isColdBoot: Bool
}
