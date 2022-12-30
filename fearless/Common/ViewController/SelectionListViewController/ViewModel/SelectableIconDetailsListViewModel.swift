import Foundation

final class SelectableIconDetailsListViewModel: SelectableViewModelProtocol {
    let title: String
    let subtitle: String?
    let icon: ImageViewModelProtocol?
    let identifier: String?

    init(
        title: String,
        subtitle: String?,
        icon: ImageViewModelProtocol?,
        isSelected: Bool,
        identifier: String?
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.identifier = identifier
        self.isSelected = isSelected
    }
}
