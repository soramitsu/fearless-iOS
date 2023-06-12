import Foundation
import SSFUtils
import Web3

struct Identity: Decodable {
    let info: IdentityInfo
}

struct IdentityInfo: Decodable {
    let additional: [IdentityAddition]
    let display: ChainData
    let legal: ChainData
    let web: ChainData
    let riot: ChainData
    let email: ChainData
    let image: ChainData
    let twitter: ChainData
}

struct IdentityAddition: Decodable {
    let field: ChainData
    let value: ChainData

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        field = try container.decode(ChainData.self)
        value = try container.decode(ChainData.self)
    }
}
