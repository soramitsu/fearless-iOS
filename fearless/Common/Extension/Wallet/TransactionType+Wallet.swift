import Foundation
import CommonWallet
import SoraFoundation

extension TransactionType {
    func toWalletType() -> WalletTransactionType {
        let isIncome: Bool

        switch self {
        case .outgoing, .extrinsic, .slash:
            isIncome = false
        case .incoming, .reward:
            isIncome = true
        }

        return WalletTransactionType(
            backendName: rawValue,
            displayName: LocalizableResource { _ in rawValue.capitalized },
            isIncome: isIncome,
            typeIcon: nil
        )
    }
}
