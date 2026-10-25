import Foundation

// sourcery: AutoMockable
public protocol ReconnectionStrategyProtocol {
    func reconnectAfter(attempt: Int) -> TimeInterval?
}

/// Waits `multiplier * e^attempt` seconds before each attempt.
///
/// With `maxAttempts` it gives up: it returns `nil` for an attempt of `maxAttempts` or more, so a
/// caller that numbers its failed attempts from 1 tries `maxAttempts` times in all. Without it, it
/// never gives up: a socket keeps reconnecting, and `SubstrateConnectionAutoBalance` relies on that
/// to move to another node.
public struct ExponentialReconnection: ReconnectionStrategyProtocol {
    let multiplier: Double
    let maxAttempts: Int?

    public init(multiplier: Double = 0.3, maxAttempts: Int? = nil) {
        self.multiplier = multiplier
        self.maxAttempts = maxAttempts
    }

    public func reconnectAfter(attempt: Int) -> TimeInterval? {
        if let maxAttempts, attempt >= maxAttempts {
            return nil
        }

        return multiplier * exp(Double(attempt))
    }
}
