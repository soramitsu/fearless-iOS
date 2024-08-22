import Foundation

struct OKXResponse<T: Decodable>: Decodable {
    let code: String
    let data: [T]
    let msg: String?
}
