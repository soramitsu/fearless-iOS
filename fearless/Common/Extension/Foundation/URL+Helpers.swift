import Foundation

extension URL {
    static func twitterAddress(for account: String) -> URL? {
        URL(string: "https://twitter.com/\(account)")
    }

    static func riotAddress(for name: String) -> URL? {
        URL(string: "https://matrix.to/#/\(name)")
    }

    func removeHttpsScheme() -> String {
        absoluteString.replacingOccurrences(of: "https://", with: "")
    }
}
