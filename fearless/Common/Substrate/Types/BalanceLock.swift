import Foundation
import BigInt
import SSFUtils
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

extension BalanceLock: LockProtocol {
    var lockType: String? {
        displayId
    }
}

enum LockReason: String, Codable {
    case fee = "Fee"
    case misc = "Misc"
    case all = "All"

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let rawValue = try container.decode(
            String.self)

        switch rawValue {
        case Self.fee.rawValue:
            self = .fee
        case Self.misc.rawValue:
            self = .misc
        case Self.all.rawValue:
            self = .all
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected type"
            )
        }
    }
}
