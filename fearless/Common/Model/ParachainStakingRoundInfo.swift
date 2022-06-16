import Foundation
import FearlessUtils

struct ParachainStakingRoundInfo: Decodable, Equatable {
    @StringCodable var current: UInt32
    @StringCodable var first: UInt32
    @StringCodable var length: UInt32
}
