import Foundation
import SSFUtils
import BigInt

typealias TokenLocks = [TokenLock]

struct TokenLock: Codable {
    @BytesCodable var id: Data
    @StringCodable var amount: BigUInt

    var displayId: String? {
        String(
            data: id,
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespaces)
    }
}

extension TokenLock: LockProtocol {
    var lockType: String? {
        displayId
    }
}
