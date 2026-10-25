import Foundation

public extension Data {
    func matchPublicKeyToAccountId(_ accountId: Data) -> Bool {
        if accountId == self {
            return true
        }

        return accountId == (try? blake2b32())
    }

    func publicKeyToAccountId() throws -> Data {
        guard count != 32 else {
            return self
        }

        return try blake2b32()
    }
}
