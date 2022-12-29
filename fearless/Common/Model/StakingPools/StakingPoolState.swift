import Foundation

enum StakingPoolState: String, Decodable {
    case open = "Open"
    case blocked = "Blocked"
    case destroying = "Destroying"

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let type = try container.decode(String.self)

        switch type {
        case Self.open.rawValue:
            self = .open
        case Self.blocked.rawValue:
            self = .blocked
        case Self.destroying.rawValue:
            self = .destroying
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected type"
            )
        }
    }
}
