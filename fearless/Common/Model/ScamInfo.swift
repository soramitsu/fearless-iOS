import Foundation
import RobinHood

struct ScamInfo: Identifiable, Codable, Equatable {
    var identifier: String {
        address
    }

    let name: String
    let address: String
    let type: String
    let subtype: String

    enum CodingKeys: String, CodingKey {
        case name
        case address
        case type
        case subtype
    }
}
