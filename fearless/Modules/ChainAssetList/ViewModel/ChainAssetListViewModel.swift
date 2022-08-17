struct ChainAssetListTableSection {
    let cellViewModels: [ChainAccountBalanceCellViewModel]
    let title: String?
    let expandable: Bool
}

struct ChainAssetListViewModel {
    let sections: [ChainAssetListTableSection]
    let isColdBoot: Bool
}
