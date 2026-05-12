import Foundation

enum CoinbaseKeys {
    static var appId: String {
        ProcessInfo.processInfo.environment["COINBASE_APP_ID"] ?? CoinbaseCIKeys.appId
    }

    static var sessionToken: String? {
        let token = ProcessInfo.processInfo.environment["COINBASE_SESSION_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (token?.isEmpty == false) ? token : nil
    }
}
