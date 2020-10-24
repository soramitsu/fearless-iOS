import Foundation

enum AccountConfirmError: Error {
    case missingAccount
    case missingEntropy
    case mismatchMnemonic
}
