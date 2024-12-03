import Foundation
import SCard

extension KYCUserStatus {
    var text: String? {
        switch self {
        case .successful: return ""
        case .rejected: return "Verification is rejected"
        case .pending: return "Verification in progress"
        case .userCanceled: return "User cancelled"
        case .none, .notStarted: return nil
        }
    }
}
