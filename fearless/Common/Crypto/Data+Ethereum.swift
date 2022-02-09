import Foundation
import keccak

// TODO: Move to library
extension Data {
    func ethereumAddressFromPublicKey() throws -> Data {
        try keccak256().suffix(20)
    }
}
