import Foundation
import SSFUtils
import BigInt

struct SetMetadataCall: Codable {
    let poolId: String
    let metadata: Data
}
