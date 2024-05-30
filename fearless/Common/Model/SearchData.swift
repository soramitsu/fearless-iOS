import Foundation

public struct SearchData: Codable, Equatable {
    public let accountId: String
    public let firstName: String
    public let lastName: String
    public let context: [String: String]?

    public init(
        accountId: String,
        firstName: String,
        lastName: String,
        context: [String: String]? = nil
    ) {
        self.accountId = accountId
        self.firstName = firstName
        self.lastName = lastName
        self.context = context
    }
}
