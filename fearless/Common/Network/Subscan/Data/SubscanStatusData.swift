import Foundation

struct SubscanStatusData<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let generatedAt: Int64?
    let data: T?
}

extension SubscanStatusData {
    var isSuccess: Bool { code == 0 }
}
