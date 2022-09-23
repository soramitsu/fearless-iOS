import Foundation

struct StakingPoolPalletID: Codable, LosslessStringConvertible, Equatable {
    var description: String

    init?(_ description: String) {
        self.description = description
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        description = try container.decode(String.self)
    }
}
