import Foundation

struct WalletsManagmentCellViewModel {
    let isSelected: Bool
    let walletName: String
    let fiatBalance: String?
    let dayChange: NSAttributedString?
    /// "incl. hidden" when `fiatBalance` counts assets hidden from the portfolio.
    var balanceCaption: String?
}
