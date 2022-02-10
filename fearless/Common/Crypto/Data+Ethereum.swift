import Foundation
import keccak
import secp256k1

// TODO: Move to library
extension Data {
    func ethereumAddressFromPublicKey() throws -> Data {
        var data = self
        if count != 64 {
            // decompress key
        }

        return try data.keccak256().suffix(20)
    }
}
