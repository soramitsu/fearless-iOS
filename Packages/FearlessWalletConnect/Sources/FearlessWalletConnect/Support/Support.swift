import Foundation

/// The time source and timers of the client. Tests move the time.
public struct WalletConnectClock: Sendable {
    public var now: @Sendable () -> Date
    public var sleep: @Sendable (_ seconds: TimeInterval) async throws -> Void

    public init(
        now: @escaping @Sendable () -> Date,
        sleep: @escaping @Sendable (_ seconds: TimeInterval) async throws -> Void
    ) {
        self.now = now
        self.sleep = sleep
    }

    public static let system = WalletConnectClock(
        now: { Date() },
        sleep: { seconds in
            guard seconds > 0 else {
                return
            }
            try await Task.sleep(nanoseconds: UInt64(min(seconds, 86400 * 30) * 1_000_000_000))
        }
    )

    var nowSeconds: Int64 {
        Int64(now().timeIntervalSince1970.rounded(.down))
    }
}

/// Where the client reports what it does. It never logs keys, topics or message contents.
public protocol WalletConnectLogging: Sendable {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

public struct SilentWalletConnectLogger: WalletConnectLogging {
    public init() {}
    public func debug(_: String) {}
    public func info(_: String) {}
    public func warning(_: String) {}
    public func error(_: String) {}
}
