import Foundation

struct SubscanExtrinsicsData: Decodable {
    let count: Int
    let extrinsics: [SubscanExtrinsicsItemData]
}

struct SubscanExtrinsicsItemData: Decodable {
    let fee: String
}
