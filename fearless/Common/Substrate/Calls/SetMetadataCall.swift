import Foundation
import SSFUtils
import Web3

struct SetMetadataCall: Codable {
    let poolId: String
    let metadata: Data
}
