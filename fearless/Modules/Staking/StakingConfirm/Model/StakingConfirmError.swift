import Foundation

enum StakingConfirmError: Error {
    case notEnoughFunds
    case missingController
    case feeNotReceived
}
