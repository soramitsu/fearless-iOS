import Foundation
import FearlessUtils
import BigInt

struct SetMetadataCall: Codable {
    let poolId: UInt32
    let metadata: Data
}
