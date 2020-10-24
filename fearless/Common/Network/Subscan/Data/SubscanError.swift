import Foundation

struct SubscanError: Error {
    let code: Int
    let message: String

    init<T>(statusData: SubscanStatusData<T>) {
        code = statusData.code
        message = statusData.message
    }
}
