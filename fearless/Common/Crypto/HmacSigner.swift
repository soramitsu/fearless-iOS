import Foundation
import CommonCrypto
import IrohaCrypto

protocol HmacSignerProtocol {
    func sign(_ originalData: Data) throws -> Data
}

enum HmacHashFunction {
    case SHA256(secretKeyData: Data)

    var algorithm: CCHmacAlgorithm {
        switch self {
        case .SHA256: return CCHmacAlgorithm(kCCHmacAlgSHA256)
        }
    }

    var digestLength: Int {
        switch self {
        case .SHA256: return Int(CC_SHA256_DIGEST_LENGTH)
        }
    }
}

final class HmacSigner {
    enum HashFunction {
        case SHA256
    }

    let hashType: HmacHashFunction

    init(hashFunction: HashFunction, secretKeyData: Data) {
        switch hashFunction {
        case .SHA256:
            hashType = .SHA256(secretKeyData: secretKeyData)
        }
    }

    private func generateHmac(_ originalData: Data, secretKeyData: Data) throws
        -> Data {
        let digestLength = hashType.digestLength
        var buffer = [UInt8](repeating: 0, count: digestLength)

        originalData.withUnsafeBytes {
            let rawOriginalDataPtr = $0.baseAddress!

            secretKeyData.withUnsafeBytes {
                let rawSecretKeyPtr = $0.baseAddress!

                CCHmac(
                    hashType.algorithm,
                    rawSecretKeyPtr,
                    secretKeyData.count,
                    rawOriginalDataPtr,
                    originalData.count,
                    &buffer
                )
            }
        }

        return Data(bytes: buffer, count: hashType.digestLength)
    }
}

extension HmacSigner: HmacSignerProtocol {
    func sign(_ originalData: Data) throws -> Data {
        switch hashType {
        case let .SHA256(secretKeyData):
            return try generateHmac(
                originalData,
                secretKeyData: secretKeyData
            )
        }
    }
}
