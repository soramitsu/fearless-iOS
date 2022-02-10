import Foundation
import keccak
import secp256k1
import BigInt

// TODO: Move to library
extension Data {
    func ethereumAddressFromPublicKey() throws -> Data {
        var data = self
        if count != 64 {
            // decompress key
            data = try EthereumUtil.decompress(key: data).suffix(64)
        }

        return try data.keccak256().suffix(20)
    }
}

private enum EthereumUtil {
    enum Error: Swift.Error {
        case secp256k1ContextUnavailable
        case publicKeyCannotBeParsed
        case publicKeyCannotBeSerialized
    }

    static func decompress(key: Data) throws -> Data {
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_NONE))
        guard let context = context else {
            secp256k1_context_destroy(context)
            throw Error.secp256k1ContextUnavailable
        }

        // Parse key

        var publicKey = secp256k1_pubkey()
        let parseResult = key.withUnsafeBytes {
            secp256k1_ec_pubkey_parse(context, &publicKey, $0, key.count)
        }

        guard parseResult != 0 else {
            secp256k1_context_destroy(context)
            throw Error.publicKeyCannotBeParsed
        }

        // Serialize

        var keyLength = 65
        var serializedPublicKey = Data(repeating: 0, count: keyLength)
        let flags = UInt32(SECP256K1_EC_UNCOMPRESSED)

        let serializeResult = serializedPublicKey.withUnsafeMutableBytes { serializedPublicKeyPtr in
            withUnsafeMutablePointer(to: &keyLength) { keyLengthPtr in
                withUnsafeMutablePointer(to: &publicKey) { publicKeyPtr in
                    secp256k1_ec_pubkey_serialize(context, serializedPublicKeyPtr, keyLengthPtr, publicKeyPtr, flags)
                }
            }
        }

        guard serializeResult != 0 else {
            secp256k1_context_destroy(context)
            throw Error.publicKeyCannotBeSerialized
        }

        secp256k1_context_destroy(context)
        return serializedPublicKey
    }
}
