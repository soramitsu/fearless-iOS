import Foundation

enum StakingConfirmError: Error {
    case notEnoughFunds
    case missingController(address: AccountAddress)
    case feeNotReceived
    case extrinsicFailed
}
