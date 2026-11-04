import Foundation

enum SubqueryDelegationAction: Int, Decodable {
    case stake = 0
    case unstake = 1
    case reward = 2
    case delegate = 3
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let value = try container.decode(Int.self)
        self = .init(rawValue: value) ?? .unknown
    }
}
