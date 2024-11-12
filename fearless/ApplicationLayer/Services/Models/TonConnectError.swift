import Foundation

struct TonConnectError: Swift.Error, Decodable {
    let statusCode: Int
    let message: String
}
