import Foundation
import IrohaCrypto

enum AccessRestoreInteractorError: Error {
    case userMissing
    case documentMissing
    case documentSignerCreationFailed
    case keystoreMissing
    case invalidPassphrase
}
