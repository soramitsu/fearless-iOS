import Foundation
import SSFUtils
import BigInt

struct CrowdloanContribution: Decodable {
    enum CodingKeys: String, CodingKey {
        case balance
        case memo
    }

    @StringCodable var balance: BigUInt
    @BytesCodable var memo: Data
}

final class CrowdloanContributionMapper: DynamicScaleDecodable {
    func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        let balance: JSON
        do {
            balance = try decoder.read(type: GenericType.balance.rawValue)
        } catch {
            balance = try decoder.read(type: KnownType.balance.rawValue)
        }
        let memo = try decoder.read(type: GenericType.bytes.rawValue)

        return JSON.dictionaryValue(
            [
                CrowdloanContribution.CodingKeys.balance.rawValue: balance,
                CrowdloanContribution.CodingKeys.memo.rawValue: memo
            ]
        )
    }
}
