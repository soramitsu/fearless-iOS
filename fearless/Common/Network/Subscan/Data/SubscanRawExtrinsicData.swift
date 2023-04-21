import Foundation
import SSFUtils

struct SubscanRawExtrinsicsData: Decodable {
    let count: Int
    let extrinsics: [JSON]?
}
