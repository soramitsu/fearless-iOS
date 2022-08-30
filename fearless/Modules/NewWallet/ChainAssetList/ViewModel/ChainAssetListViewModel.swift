struct ChainAssetListTableSection: Hashable {
    let title: String?
    let expandable: Bool
}

struct ChainAssetListViewModel {
    let sections: [ChainAssetListTableSection]
    let cellsForSections: [ChainAssetListTableSection: [ChainAccountBalanceCellViewModel]]
    let isColdBoot: Bool
}
