import Foundation

final class SelectableIconDetailsListViewModel: SelectableViewModelProtocol {
    let title: String
    let subtitle: String?
    let icon: ImageViewModelProtocol?
    let identifire: String?

    init(
        title: String,
        subtitle: String?,
        icon: ImageViewModelProtocol?,
        isSelected: Bool,
        identifire: String?
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.identifire = identifire
        self.isSelected = isSelected
    }
}
