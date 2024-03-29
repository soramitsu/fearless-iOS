import Foundation
import CommonCrypto

extension Data {
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
}

public extension String {
    func sha256() -> Data {
        if let stringData = data(using: String.Encoding.utf8) {
            return stringData.sha256()
        }
        return Data()
    }
}
