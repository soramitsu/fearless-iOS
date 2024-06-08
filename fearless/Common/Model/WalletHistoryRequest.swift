import Foundation

struct WalletHistoryRequest: Codable, Equatable {
    var assets: [String]?
    var filter: String?
    var fromDate: Date?
    var toDate: Date?
    var type: String?

    init(assets: [String]) {
        self.assets = assets
    }
}
