import Foundation

enum CrossChainFundsPermissionMode {
    case none
    case approve(dexTokenApproveAddress: String)
    case revoke(dexTokenApproveAddress: String)
    
    func title(for locale: Locale) -> String? {
        switch self {
        case .approve:
            return "Spending Approval"
        case .revoke:
            return "Revoke approval"
        case .none:
            return nil
        }
    }
    
    func warningText(for locale: Locale) -> String? {
        switch self {
        case .approve:
            return "Spending approval ensures secure token access for smart contracts and dApps on EVM chains."
        case .revoke:
            return "Please clear or revoke the current amount to proceed with a new transaction."
        case .none:
            return nil
        }
    }
    
    var dexTokenApproveAddress: String? {
        switch self {
        case let .approve(dexTokenApproveAddress):
            return dexTokenApproveAddress
        case let .revoke(dexTokenApproveAddress):
            return dexTokenApproveAddress
        default:
            return nil
        }
    }
}

struct CrossChainFundsPermissionViewModel {
    let titleLabelText: String?
    let amountLabelText: NSAttributedString?
    let fromViewModel: TitleMultiValueViewModel?
    let requestFromViewModel: TitleMultiValueViewModel?
    let amountViewModel: BalanceViewModelProtocol?
    let warningText: String?
    let symbolViewModel: SymbolViewModel
}
