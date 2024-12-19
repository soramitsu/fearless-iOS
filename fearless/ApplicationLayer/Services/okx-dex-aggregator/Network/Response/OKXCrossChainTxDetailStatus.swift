import Foundation

enum OKXCrossChainTxDetailStatus: String {
    case waiting = "WAITING" // (Order processing)
    case fromSuccess = "FROM_SUCCESS" // (Source swap success)
    case fromFailure = "FROM_FAILURE" // (Source swap failure)
    case bridgePending = "BRIDGE_PENDING" // (Bridge pending)
    case bridgeSuccess = "BRIDGE_SUCCESS" // (Bridge success)
    case success = "SUCCESS" // (Order success)
    case refund = "REFUND" // (Order failure, refund)
    case notFound = "NOT_FOUND"

    init(txDetailStatus: String?) {
        switch txDetailStatus?.lowercased() {
        case "pending":
            self = .waiting
        case "success":
            self = .success
        case "fail":
            self = .fromFailure
        default:
            self = .notFound
        }
    }
}
