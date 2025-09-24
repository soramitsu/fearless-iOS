import Foundation

enum SelectValidatorsConfirmError: Error {
    case notEnoughFunds
    case missingController(address: AccountAddress)
    case feeNotReceived
    case extrinsicFailed
}
