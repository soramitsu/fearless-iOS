import Foundation

enum CoinbaseKeys {
    static var sessionToken: String? {
        sessionToken(
            environment: ProcessInfo.processInfo.environment,
            generatedValue: CoinbaseCIKeys.sessionToken
        )
    }

    static func sessionToken(environment: [String: String], generatedValue: String) -> String? {
        let environmentToken = environment["COINBASE_SESSION_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let token: String

        if let environmentToken, !environmentToken.isEmpty {
            token = environmentToken
        } else {
            token = generatedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return token.isEmpty ? nil : token
    }
}
