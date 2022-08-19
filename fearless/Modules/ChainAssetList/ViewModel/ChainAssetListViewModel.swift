struct ChainAssetListTableSection {
    let title: String?
    let expandable: Bool
}

extension ChainAssetListTableSection: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(expandable)
    }
}

extension ChainAssetListTableSection: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title && lhs.expandable == rhs.expandable
    }
}

struct ChainAssetListViewModel {
    let sections: [ChainAssetListTableSection]
    let cellsForSections: [ChainAssetListTableSection: [ChainAccountBalanceCellViewModel]]
    let isColdBoot: Bool
}
