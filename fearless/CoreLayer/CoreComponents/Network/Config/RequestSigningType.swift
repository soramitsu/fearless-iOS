import Foundation

enum RequestSigningType {
    case none
    case bearer
    case custom(signer: RequestSigner)
}
