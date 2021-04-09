import CommonCrypto
import Foundation

enum HashFunction {
    case MD5, SHA1, SHA224, SHA256, SHA384, SHA512

    var algorithm: CCHmacAlgorithm {
        var result: Int = 0

        switch self {
        case .MD5: result = kCCHmacAlgMD5
        case .SHA1: result = kCCHmacAlgSHA1
        case .SHA224: result = kCCHmacAlgSHA224
        case .SHA256: result = kCCHmacAlgSHA256
        case .SHA384: result = kCCHmacAlgSHA384
        case .SHA512: result = kCCHmacAlgSHA512
        }

        return CCHmacAlgorithm(result)
    }

    var digestLength: Int {
        var length: Int32 = 0

        switch self {
        case .MD5: length = CC_MD5_DIGEST_LENGTH
        case .SHA1: length = CC_SHA1_DIGEST_LENGTH
        case .SHA224: length = CC_SHA224_DIGEST_LENGTH
        case .SHA256: length = CC_SHA256_DIGEST_LENGTH
        case .SHA384: length = CC_SHA384_DIGEST_LENGTH
        case .SHA512: length = CC_SHA512_DIGEST_LENGTH
        }
        
        return Int(length)
    }
}

extension String {
    func toHMAC(algorithm: HashFunction, key: String) -> String {
        let dataString = cString(using: String.Encoding.utf8)
        let dataStringLength = Int(lengthOfBytes(using: String.Encoding.utf8))

        let keyString = key.cString(using: String.Encoding.utf8)
        let keyLen = Int(key.lengthOfBytes(using: String.Encoding.utf8))

        let digestLength = algorithm.digestLength
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLength)

        CCHmac(algorithm.algorithm, keyString!, keyLen, dataString!, dataStringLength, result)

        let digest = getDigest(from: result, length: digestLength)

        result.deallocate()

        return digest
    }

    private func getDigest(from result: UnsafeMutablePointer<CUnsignedChar>, length: Int) -> String {
        let hash = NSMutableString()

        for index in 0 ..< length {
            hash.appendFormat("%02x", result[index])
        }

        return String(hash).lowercased()
    }
}
