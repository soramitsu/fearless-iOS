import Foundation
import UIKit

typealias WarningAlertButtonHandler = (() -> Void)

struct WarningAlertConfig {
    let title: String?
    let iconImage: UIImage?
    let text: String?
    let buttonTitle: String?
    let blocksUi: Bool
}
