import Foundation

class SwitchFilterItem: BaseFilterItem {
    var selected: Bool = true

    init(
        id: String,
        title: String,
        selected: Bool
    ) {
        self.selected = selected

        super.init(
            id: id,
            title: title
        )
    }

    override func reset() {
        selected = true
    }
}
