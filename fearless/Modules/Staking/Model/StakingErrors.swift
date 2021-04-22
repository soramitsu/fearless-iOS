import Foundation

enum StakingConfirmError: Error {
    case notEnoughFunds
    case missingController(address: AccountAddress)
    case feeNotReceived
    case extrinsicFailed
}

enum StakingPayoutConfirmError: Error {
    case notEnoughFunds
    case feeNotReceived
    case extrinsicFailed
    case tinyPayout
}
