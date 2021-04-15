import Foundation
import FearlessUtils

struct SubscanRawExtrinsicsData: Decodable {
    let count: Int
    let extrinsics: [JSON]?
}
