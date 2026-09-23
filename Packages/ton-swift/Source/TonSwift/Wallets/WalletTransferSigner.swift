import Foundation
import TweetNacl

public enum WalletTransferSignerError: Swift.Error {
    case failedToSignMessage
}

public protocol WalletTransferSigner {
    func signMessage(_ message: Data) throws -> Data
}

public struct WalletTransferSecretKeySigner: WalletTransferSigner {
    private let secretKey: Data
    
    public init(secretKey: Data) {
        self.secretKey = secretKey
    }
    
    public func signMessage(_ message: Data) throws -> Data {
        do {
            return try NaclSign.signDetached(message: message, secretKey: secretKey)
        } catch {
            throw WalletTransferSignerError.failedToSignMessage
        }
    }
}

public struct WalletTransferEmptyKeySigner: WalletTransferSigner {
    public init() {}
    
    public func signMessage(_ message: Data) throws -> Data {
        guard let data = String(repeating: "0", count: .signatureBytesCount).data(using: .utf8) else {
            throw WalletTransferSignerError.failedToSignMessage
        }
        return data
    }
}

private extension Int {
    static let signatureBytesCount = 64
}
