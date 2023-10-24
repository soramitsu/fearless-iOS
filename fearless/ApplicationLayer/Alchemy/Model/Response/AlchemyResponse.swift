import Foundation

struct AlchemyResponse<T: Decodable>: Decodable {
    let jsonrpc: String
    let id: UInt32
    let result: T
}
