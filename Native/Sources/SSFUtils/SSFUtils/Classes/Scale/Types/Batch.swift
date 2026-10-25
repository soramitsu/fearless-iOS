import Foundation

public struct BatchArgs: Codable {
    public let calls: [JSON]

    public init(calls: [JSON]) {
        self.calls = calls
    }
}
