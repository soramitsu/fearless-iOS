import Foundation

enum CrossChainFundsPermissionMode {
    case none
    case approve(dexTokenApproveAddress: String)
    case revoke(dexTokenApproveAddress: String)
    
    func title(amount: String, locale: Locale) -> String? {
        switch self {
        case .approve:
            return R.string.localizable.erc20FundsPermissionApproveTitle(
                amount,
                preferredLanguages: locale.rLanguages
            )
        case .revoke:
            return R.string.localizable.erc20FundsPermissionRevokeTitle(
                amount,
                preferredLanguages: locale.rLanguages
            )
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
    let amountLabelText: NSAttributedString?
    let fromViewModel: TitleMultiValueViewModel?
    let requestFromViewModel: TitleMultiValueViewModel?
    let amountViewModel: BalanceViewModelProtocol?
    let warningText: String?
    let symbolViewModel: SymbolViewModel
    let confirmButtonTitle: String?
}
