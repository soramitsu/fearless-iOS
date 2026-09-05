import Foundation
import CommonCrypto

public let pbkdf2Sha512Iterations = 100000

public func pbkdf2Sha512(phrase: Data, salt: Data, iterations: Int = pbkdf2Sha512Iterations, keyLength: Int = 64) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: keyLength)
    
    _ = bytes.withUnsafeMutableBytes { (outputBytes: UnsafeMutableRawBufferPointer) in
        CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            phrase.map({ Int8(bitPattern: $0) }),
            phrase.count,
            [UInt8](salt),
            salt.count,
            CCPBKDFAlgorithm(kCCPRFHmacAlgSHA512),
            UInt32(iterations),
            outputBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
            keyLength
        )
    }
    
    return bytes
}
