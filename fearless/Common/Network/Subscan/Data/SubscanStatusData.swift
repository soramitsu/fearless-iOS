import Foundation

struct SubscanStatusData<T: Codable>: Codable {
    let code: Int
    let message: String
    let generatedAt: Int64?
    let data: T?
}

extension SubscanStatusData {
    var isSuccess: Bool { code == 0 }
}
