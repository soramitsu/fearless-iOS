import Foundation

enum AccountOperationFactoryError: Error {
    case invalidKeystore
    case keypairFactoryFailure
    case unsupportedNetwork
    case decryption
    case missingUsername
}
