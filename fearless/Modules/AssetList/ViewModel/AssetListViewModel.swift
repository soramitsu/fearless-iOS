struct AssetListTableSection {
    let cellViewModels: [ChainAccountBalanceCellViewModel]
    let title: String?
    let expandable: Bool
}

struct AssetListViewModel {
    let sections: [AssetListTableSection]
    let isColdBoot: Bool
}
