import Foundation
import UIKit

protocol TitleSwitchTableViewCellModelDelegate: AnyObject {
    func switchOptionChangeState(option: FilterOption, isOn: Bool)
}

class TitleSwitchTableViewCellModel {
    let icon: UIImage?
    let title: String
    let switchIsOn: Bool
    let filterOption: FilterOption

    weak var delegate: TitleSwitchTableViewCellModelDelegate?

    init(
        icon: UIImage?,
        title: String,
        switchIsOn: Bool,
        filterOption: FilterOption
    ) {
        self.icon = icon
        self.title = title
        self.switchIsOn = switchIsOn
        self.filterOption = filterOption
    }
}

extension TitleSwitchTableViewCellModel: TitleSwitchTableViewCellDelegate {
    func switchOptionChangeState(isOn: Bool) {
        delegate?.switchOptionChangeState(option: filterOption, isOn: isOn)
    }
}
