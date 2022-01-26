import Foundation

class SwitchFilterTableCellViewModel: FilterCellViewModel {
    let enabled: Bool

    init(id: String, title: String, enabled: Bool) {
        self.enabled = enabled

        super.init(id: id, title: title)
    }
}
