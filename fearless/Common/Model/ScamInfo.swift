import Foundation
import RobinHood

struct ScamInfo: Identifiable, Codable, Equatable {
    var identifier: String {
        address
    }

    let name: String
    let address: String
    let type: ScamType
    let subtype: String

    enum CodingKeys: String, CodingKey {
        case name
        case address
        case type
        case subtype
    }

    enum ScamType: String, Codable {
        case unknown
        case scam
        case donation
        case exchange
        case sanctions
    }
}
