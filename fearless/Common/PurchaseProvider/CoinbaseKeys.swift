import Foundation

enum CoinbaseKeys {
    static var appId: String {
        ProcessInfo.processInfo.environment["COINBASE_APP_ID"] ?? CoinbaseCIKeys.appId
    }
}
