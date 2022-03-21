import Foundation

struct LearnMoreViewModel {
    let iconViewModel: ImageViewModelProtocol?
    let title: String
    let subtitle: String?
    let subtitleUnderLined: Bool

    init(
        iconViewModel: ImageViewModelProtocol?,
        title: String,
        subtitle: String? = nil,
        subtitleUnderLined: Bool = false
    ) {
        self.iconViewModel = iconViewModel
        self.title = title
        self.subtitle = subtitle
        self.subtitleUnderLined = subtitleUnderLined
    }
}
