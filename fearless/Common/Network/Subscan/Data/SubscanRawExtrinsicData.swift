import Foundation
import SSFUtils
import SSFModels

struct SubscanRawExtrinsicsData: Decodable {
    let count: Int
    let extrinsics: [JSON]?
}
