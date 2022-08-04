import Foundation

enum StakingPoolState: String, Decodable {
    case open
    case blocked
    case destroying
}
