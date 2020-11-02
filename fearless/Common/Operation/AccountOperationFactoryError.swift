import Foundation

enum AccountOperationFactoryError: Error {
    case invalidKeystore
    case unsupportedNetwork
    case decryption
    case missingUsername
}
