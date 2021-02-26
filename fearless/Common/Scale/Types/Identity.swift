import Foundation
import FearlessUtils
import BigInt

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

    var name: String? {
        if case .raw(let value) = display {
            return String(data: value, encoding: .utf8)
        } else {
            return nil
        }
    }
}

struct IdentityAddition: Decodable {
    let field: ChainData
    let value: ChainData
}
