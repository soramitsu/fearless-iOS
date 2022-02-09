import Foundation

final class SelectableIconDetailsListViewModel: SelectableViewModelProtocol {
    let title: String
    let subtitle: String
    let icon: ImageViewModelProtocol?

    init(title: String, subtitle: String, icon: ImageViewModelProtocol?, isSelected: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isSelected = isSelected
    }
}
