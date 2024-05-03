import Foundation

public struct WalletHistoryRequest: Codable, Equatable {
    public var assets: [String]?
    public var filter: String?
    public var fromDate: Date?
    public var toDate: Date?
    public var type: String?

    public init(assets: [String]) {
        self.assets = assets
    }

    public init() {}
}
