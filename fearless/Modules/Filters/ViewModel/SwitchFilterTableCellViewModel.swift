import Foundation

protocol SwitchFilterTableCellViewModelDelegate: AnyObject {
    func filterStateChanged(filterId: String, selected: Bool)
}

class SwitchFilterTableCellViewModel: FilterCellViewModel {
    private weak var delegate: SwitchFilterTableCellViewModelDelegate?

    let enabled: Bool

    init(id: String, title: String, enabled: Bool, delegate: SwitchFilterTableCellViewModelDelegate?) {
        self.enabled = enabled
        self.delegate = delegate

        super.init(id: id, title: title)
    }
}

extension SwitchFilterTableCellViewModel: SwitchFilterTableCellDelegate {
    func switcherValueChanged(isOn: Bool) {
        delegate?.filterStateChanged(filterId: id, selected: isOn)
    }
}
