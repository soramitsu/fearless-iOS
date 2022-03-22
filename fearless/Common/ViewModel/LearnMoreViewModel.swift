import Foundation

struct LearnMoreViewModel {
    let iconViewModel: ImageViewModelProtocol?
    let title: String
    let subtitle: String?
    let subtitleUnderlined: Bool

    init(
        iconViewModel: ImageViewModelProtocol?,
        title: String,
        subtitle: String? = nil,
        subtitleUnderlined: Bool = false
    ) {
        self.iconViewModel = iconViewModel
        self.title = title
        self.subtitle = subtitle
        self.subtitleUnderlined = subtitleUnderlined
    }
}
