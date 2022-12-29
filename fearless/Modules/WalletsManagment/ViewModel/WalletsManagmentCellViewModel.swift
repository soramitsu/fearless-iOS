import Foundation

struct WalletsManagmentCellViewModel {
    let isSelected: Bool
    let address: String
    let walletName: String
    let fiatBalance: String?
    let dayChange: NSAttributedString?
}
