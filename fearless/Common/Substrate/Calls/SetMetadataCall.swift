import Foundation
import FearlessUtils
import BigInt

struct SetMetadataCall: Codable {
    let poolId: String
    let metadata: Data
}
