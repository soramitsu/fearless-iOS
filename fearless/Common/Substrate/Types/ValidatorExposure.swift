import Foundation
import SSFUtils
import BigInt

struct ValidatorExposurePage: Codable {
    let others: [IndividualExposure]
    @StringCodable var pageTotal: BigUInt

    static func + (lhs: ValidatorExposurePage, rhs: ValidatorExposurePage) -> ValidatorExposurePage {
        ValidatorExposurePage(others: lhs.others + rhs.others, pageTotal: lhs.pageTotal + rhs.pageTotal)
    }
}

struct ValidatorExposureMetadata: Codable {
    @StringCodable var total: BigUInt
    @StringCodable var own: BigUInt
    @StringCodable var nominatorCount: UInt32
    @StringCodable var pageCount: UInt32
}

struct ValidatorExposure: Codable {
    @StringCodable var total: BigUInt
    @StringCodable var own: BigUInt
    let others: [IndividualExposure]
}

struct IndividualExposure: Codable {
    enum CodingKeys: String, CodingKey {
        case who
        case value
    }

    var who: Data
    @StringCodable var value: BigUInt

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            who = try container.decode(Data.self, forKey: .who)
        } catch {
            let whoAddress = try container.decode(String.self, forKey: .who)
            who = try Data(hexStringSSF: whoAddress)
        }

        value = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .value).value
    }
}
