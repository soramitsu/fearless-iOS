import Foundation
import FearlessUtils

struct SubscanExtrinsicsData: Decodable {
    let count: Int
    let extrinsics: [SubscanExtrinsicsItemData]?
}

struct SubscanExtrinsicsItemData: Decodable {
    let params: JSON?
}
