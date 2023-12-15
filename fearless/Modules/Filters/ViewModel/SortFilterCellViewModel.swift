import Foundation

class SortFilterCellViewModel: FilterCellViewModel {
    var selected: Bool

    init(id: String, title: String, selected: Bool) {
        self.selected = selected
        super.init(id: id, title: title)
    }
}
