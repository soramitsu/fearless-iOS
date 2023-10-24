import Foundation
import BigInt

struct AlchemyNftMediaInfo: Decodable {
    let gateway: String?
    let thumbnail: String?
    let raw: String?
    let format: String?
    let bytes: UInt64?
}
