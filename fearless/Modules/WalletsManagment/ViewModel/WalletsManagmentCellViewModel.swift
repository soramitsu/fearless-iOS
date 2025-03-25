import Foundation
import UIKit

struct WalletsManagmentCellViewModel {
    let isSelected: Bool
    let walletName: String
    let icon: UIImage
    let fiatBalance: String?
    let dayChange: NSAttributedString?
    let accountScoreViewModel: AccountScoreViewModel?
    let optionsAvailable: Bool
}
