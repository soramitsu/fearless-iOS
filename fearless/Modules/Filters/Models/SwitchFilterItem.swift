import Foundation

class SwitchFilterItem: BaseFilterItem {
    var selected: Bool = false

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
}
