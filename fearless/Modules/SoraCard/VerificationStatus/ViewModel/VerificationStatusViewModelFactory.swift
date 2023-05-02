import Foundation

protocol VerificationStatusViewModelFactoryProtocol {
    func buildStatusViewModel(from status: SCKYCUserStatus?, hasFreeAttempts: Bool) -> SoraCardStatus
}

final class VerificationStatusViewModelFactory: VerificationStatusViewModelFactoryProtocol {
    func buildStatusViewModel(from status: SCKYCUserStatus?, hasFreeAttempts: Bool) -> SoraCardStatus {
        guard let status = status else {
            return .failure
        }

        switch status {
        case .notStarted, .userCanceled:
            return .failure
        case .pending:
            return .pending
        case .successful:
            return .success
        case .rejected:
            return .rejected(hasFreeAttempts: hasFreeAttempts)
        }
    }
}
