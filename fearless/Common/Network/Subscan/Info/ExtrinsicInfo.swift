import Foundation

struct ExtrinsicInfo: Codable {
    let address: String
    let row: Int
    let page: Int
    let module: String?
    let call: String?
}
