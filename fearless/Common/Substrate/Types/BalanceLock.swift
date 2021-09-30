import Foundation
import BigInt
import FearlessUtils
import SoraFoundation

struct BalanceLock: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case amount
        case reasons
    }

    @BytesCodable var identifier: Data
    @StringCodable var amount: BigUInt
    let reasons: LockReason

    var displayId: String? {
        String(
            data: identifier,
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespaces)
    }
}

enum LockReason: UInt8, Codable {
    case fee
    case misc
    case all
}
