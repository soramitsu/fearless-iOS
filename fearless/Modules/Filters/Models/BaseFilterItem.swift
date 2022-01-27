import Foundation

class BaseFilterItem {
    var id: String
    var title: String

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    func reset() {
        assertionFailure("This method MUST be overriden by subclass")
    }
}
