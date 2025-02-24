import Foundation

struct TitleMultiValueViewModel {
    let title: String?
    let subtitle: String?
    let detailsButtonVisible: Bool
    
    init(title: String?, subtitle: String?, detailsButtonVisible: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.detailsButtonVisible = detailsButtonVisible
    }
}
