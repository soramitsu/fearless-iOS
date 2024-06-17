import Foundation
import UIKit
import SSFModels

class TitleSwitchTableViewCellModel {
    let icon: UIImage?
    let title: String
    let switchIsOn: Bool

    init(
        icon: UIImage?,
        title: String,
        switchIsOn: Bool
    ) {
        self.icon = icon
        self.title = title
        self.switchIsOn = switchIsOn
    }
}
