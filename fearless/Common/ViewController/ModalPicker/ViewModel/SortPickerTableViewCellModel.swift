class SortPickerTableViewCellModel {
    let title: String
    let switchIsOn: Bool
    let sortOption: PoolSortOption

    init(
        title: String,
        switchIsOn: Bool,
        sortOption: PoolSortOption
    ) {
        self.title = title
        self.switchIsOn = switchIsOn
        self.sortOption = sortOption
    }
}
