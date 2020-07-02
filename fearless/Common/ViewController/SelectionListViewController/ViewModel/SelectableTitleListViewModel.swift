import Foundation

final class SelectableTitleListViewModel: SelectableViewModelProtocol {
    var title: String

    init(title: String, isSelected: Bool = false) {
        self.title = title
        self.isSelected = isSelected
    }
}
