import Foundation

struct ParachainStakingRoundInfo: Decodable, Equatable {
    let current: UInt32
    let first: UInt32
    let length: UInt32
}
