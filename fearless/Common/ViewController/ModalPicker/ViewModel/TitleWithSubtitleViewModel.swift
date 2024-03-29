import Foundation

struct TitleWithSubtitleViewModel: Equatable {
    let title: String
    let subtitle: String

    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    init(title: String) {
        self.title = title
        subtitle = ""
    }
}
