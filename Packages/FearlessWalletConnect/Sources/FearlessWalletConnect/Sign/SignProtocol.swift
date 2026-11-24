import Foundation

/// How long the relay keeps a message, its tag (which the relay and peers' push services read), and whether it
/// prompts the receiving wallet.
struct PublishOptions: Equatable, Sendable {
    let ttl: Int
    let tag: Int
    let prompt: Bool

    init(ttl: Int, tag: Int, prompt: Bool = false) {
        self.ttl = ttl
        self.tag = tag
        self.prompt = prompt
    }
}

/// The WalletConnect v2 Sign and pairing methods, with each one's relay lifetime and tag.
enum SignProtocol {
    static let fiveMinutes = 300
    static let fifteenMinutes = 900
    static let oneDay = 86400
    static let sevenDays = 7 * oneDay
    static let thirtyDays = 30 * oneDay

    static let proposeRequest = PublishOptions(ttl: fiveMinutes, tag: 1100, prompt: true)
    static let proposeResponse = PublishOptions(ttl: fiveMinutes, tag: 1101)
    static let proposeReject = PublishOptions(ttl: fiveMinutes, tag: 1120)
    static let proposeAutoReject = PublishOptions(ttl: fiveMinutes, tag: 1121)
    static let settleRequest = PublishOptions(ttl: fiveMinutes, tag: 1102)
    static let settleResponse = PublishOptions(ttl: fiveMinutes, tag: 1103)
    static let updateRequest = PublishOptions(ttl: oneDay, tag: 1104)
    static let updateResponse = PublishOptions(ttl: oneDay, tag: 1105)
    static let extendRequest = PublishOptions(ttl: oneDay, tag: 1106)
    static let extendResponse = PublishOptions(ttl: oneDay, tag: 1107)
    static let sessionRequest = PublishOptions(ttl: fifteenMinutes, tag: 1108, prompt: true)
    static let sessionRequestResponse = PublishOptions(ttl: fifteenMinutes, tag: 1109)
    static let eventRequest = PublishOptions(ttl: fiveMinutes, tag: 1110, prompt: true)
    static let eventResponse = PublishOptions(ttl: fiveMinutes, tag: 1111)
    static let deleteRequest = PublishOptions(ttl: oneDay, tag: 1112)
    static let deleteResponse = PublishOptions(ttl: oneDay, tag: 1113)
    static let pingRequest = PublishOptions(ttl: oneDay, tag: 1114)
    static let pingResponse = PublishOptions(ttl: oneDay, tag: 1115)
    static let pairingDeleteRequest = PublishOptions(ttl: oneDay, tag: 1000)
    static let pairingDeleteResponse = PublishOptions(ttl: oneDay, tag: 1001)
    static let pairingPingRequest = PublishOptions(ttl: 30, tag: 1002)
    static let pairingPingResponse = PublishOptions(ttl: 30, tag: 1003)
    static let unregisteredMethod = PublishOptions(ttl: oneDay, tag: 0)
}

/// The Sign protocol's error codes. Peers compare the codes, so the protocol fixes them.
enum SignError {
    static func invalidMethod(_ context: String? = nil) -> JSONRPCError {
        error(1001, "Invalid method.", context)
    }

    static func unauthorizedMethod(_ context: String? = nil) -> JSONRPCError {
        error(3001, "Unauthorized method.", context)
    }

    static func unauthorizedUpdateRequest() -> JSONRPCError {
        error(3003, "Unauthorized update request.", nil)
    }

    static func unauthorizedExtendRequest() -> JSONRPCError {
        error(3004, "Unauthorized extend request.", nil)
    }

    static func unsupportedChains(_ context: String? = nil) -> JSONRPCError {
        error(5100, "Unsupported chains.", context)
    }

    static func unsupportedMethods(_ context: String? = nil) -> JSONRPCError {
        error(5101, "Unsupported methods.", context)
    }

    static let userDisconnected = error(6000, "User disconnected.", nil)

    static func unsupportedWcMethod(_ method: String) -> JSONRPCError {
        error(10001, "Unsupported wc_ method.", method)
    }

    private static func error(_ code: Int, _ message: String, _ context: String?) -> JSONRPCError {
        guard let context, !context.isEmpty else {
            return JSONRPCError(code: code, message: message)
        }
        return JSONRPCError(code: code, message: "\(message) \(context)")
    }
}
