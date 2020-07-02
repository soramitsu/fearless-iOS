import Foundation

final class SelectableSubtitleListViewModel: SelectableViewModelProtocol {
    var title: String
    var subtitle: String

    init(title: String, subtitle: String, isSelected: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
    }
}
