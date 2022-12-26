import Foundation

final class SelectableSubtitleListViewModel: SelectableViewModelProtocol {
    var title: String
    var subtitle: String?
    var isExpand: Bool

    init(title: String, subtitle: String?, isSelected: Bool = false, isExpand: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.isExpand = isExpand
        self.isSelected = isSelected
    }
}
