import Foundation

struct ViewSelectorAction {
    let title: String
    let selector: Selector?

    init(title: String, selector: Selector?) {
        self.title = title
        self.selector = selector
    }
}
