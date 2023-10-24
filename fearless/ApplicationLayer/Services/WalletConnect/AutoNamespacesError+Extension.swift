import Foundation
import WalletConnectSign

extension AutoNamespacesError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .requiredChainsNotSatisfied:
            return "requiredChainsNotSatisfied"
        case .requiredAccountsNotSatisfied:
            return "requiredAccountsNotSatisfied"
        case .requiredMethodsNotSatisfied:
            return "requiredMethodsNotSatisfied"
        case .requiredEventsNotSatisfied:
            return "requiredEventsNotSatisfied"
        }
    }
}
