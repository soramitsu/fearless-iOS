import Foundation

protocol UniversalWalletHTTPTransport {
    func perform(_ request: URLRequest) async throws -> Data
}

enum UniversalWalletHTTPTransportError: Error, Equatable {
    case invalidResponse
    case httpStatusCode(Int, Data)
    /// HTTP 429 or 503: the service asked the app to slow down. `retryAfter` is the
    /// `Retry-After` header in seconds when the service sent one.
    case rateLimited(statusCode: Int, retryAfter: TimeInterval?)
}

final class URLSessionUniversalWalletHTTPTransport: UniversalWalletHTTPTransport {
    /// A public indexer can ask for a pause far longer than a wallet should honour blindly.
    static let maxRetryAfter: TimeInterval = 15 * 60

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UniversalWalletHTTPTransportError.invalidResponse
        }
        if httpResponse.statusCode == 429 || httpResponse.statusCode == 503 {
            throw UniversalWalletHTTPTransportError.rateLimited(
                statusCode: httpResponse.statusCode,
                retryAfter: Self.retryAfter(from: httpResponse.value(forHTTPHeaderField: "Retry-After"))
            )
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw UniversalWalletHTTPTransportError.httpStatusCode(httpResponse.statusCode, data)
        }

        return data
    }

    /// `Retry-After` is either delay seconds or an HTTP date (RFC 9110 §10.2.3).
    static func retryAfter(from header: String?, now: Date = Date()) -> TimeInterval? {
        guard let value = header?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        let seconds: TimeInterval
        if let delay = TimeInterval(value), delay.isFinite {
            seconds = delay
        } else if let date = httpDateFormatter.date(from: value) {
            seconds = date.timeIntervalSince(now)
        } else {
            return nil
        }

        return min(max(seconds, 0), maxRetryAfter)
    }

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter
    }()
}
