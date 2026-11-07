import Foundation

/// Strategic-bonus APY of one Polkaswap XYK pool, as the SORA indexer reports it.
///
/// `id` is the indexer's pool identifier. The Soramitsu indexer (`pi.soramitsu.io`) reports
/// `<base asset id>-<target asset id>`; the retired SubQuery project reported the pool's
/// reserves account address. `PolkaswapPoolApyMapper` maps both forms to the reserves
/// address that the liquidity-pool screens compare against.
public struct PolkaswapPoolStrategicBonusApy: Equatable {
    public let id: String
    public let strategicBonusApy: Decimal?

    public init(id: String, strategicBonusApy: Decimal?) {
        self.id = id
        self.strategicBonusApy = strategicBonusApy
    }
}

public enum PolkaswapAPYWorkerError: Swift.Error, Equatable {
    case invalidEndpoint
    case invalidStatusCode(Int)
    case responseTooLarge
    case invalidResponse
    case indexerError
    case invalidPagination
    case paginationLimit
}

public protocol PolkaswapAPYWorker {
    func getAPYInfo() async throws -> [PolkaswapPoolStrategicBonusApy]
}

/// Reads pool strategic-bonus APY from the SORA indexer with a plain HTTPS GraphQL request.
///
/// This replaces the closed-source `sorawallet` Kotlin/Native client, which sent the same
/// `poolXYKs { id strategicBonusApy }` query to a SubQuery project that no longer answers.
/// Only the fixed Soramitsu indexer host is accepted, redirects are refused, nothing is
/// cached or logged, and pagination and value sizes are bounded.
public final class PolkaswapAPYWorkerDefault: PolkaswapAPYWorker {
    public static let soraIndexerURL = URL(string: "https://pi.soramitsu.io/graphql")!

    enum Constants {
        static let pageSize = 100
        static let maximumPages = 50
        static let maximumCursorBytes = 4096
        static let maximumIdentifierBytes = 256
        static let maximumValueBytes = 64
        static let maximumResponseBytes = 2 * 1024 * 1024
        static let maximumApy = Decimal(1_000_000)
        static let allowedHosts: Set<String> = ["pi.soramitsu.io"]
        static let operationName = "FearlessPoolStrategicBonusApy"
        static let query = """
        query FearlessPoolStrategicBonusApy($first: Int!, $after: Cursor) {
          entities: poolXYKs(first: $first, after: $after, orderBy: [ID_ASC]) {
            nodes {
              id
              strategicBonusApy
            }
            pageInfo {
              hasNextPage
              endCursor
            }
          }
        }
        """
    }

    private let endpoint: URL
    private let session: URLSession

    /// One session for every worker: a URLSession keeps its delegate until invalidated, and
    /// screens build a new worker each time they open.
    private static let sharedSession = makeSession()

    public init(
        endpoint: URL = PolkaswapAPYWorkerDefault.soraIndexerURL,
        session: URLSession? = nil
    ) {
        self.endpoint = endpoint
        self.session = session ?? Self.sharedSession
    }

    public func getAPYInfo() async throws -> [PolkaswapPoolStrategicBonusApy] {
        guard Self.isAllowedEndpoint(endpoint) else {
            throw PolkaswapAPYWorkerError.invalidEndpoint
        }

        var values: [PolkaswapPoolStrategicBonusApy] = []
        var seenIdentifiers = Set<String>()
        var seenCursors = Set<String>()
        var cursor: String?

        for _ in 0 ..< Constants.maximumPages {
            let page = try await loadPage(after: cursor)

            for node in page.nodes {
                guard
                    Self.isValidIdentifier(node.id),
                    seenIdentifiers.insert(node.id.lowercased()).inserted
                else {
                    throw PolkaswapAPYWorkerError.invalidResponse
                }

                values.append(
                    PolkaswapPoolStrategicBonusApy(
                        id: node.id,
                        strategicBonusApy: Self.validatedApy(node.strategicBonusApy)
                    )
                )
            }

            guard let hasNextPage = page.pageInfo.hasNextPage else {
                throw PolkaswapAPYWorkerError.invalidResponse
            }

            if !hasNextPage {
                return values
            }

            guard
                !page.nodes.isEmpty,
                let endCursor = page.pageInfo.endCursor,
                !endCursor.isEmpty,
                endCursor.utf8.count <= Constants.maximumCursorBytes,
                seenCursors.insert(endCursor).inserted
            else {
                throw PolkaswapAPYWorkerError.invalidPagination
            }

            cursor = endCursor
        }

        throw PolkaswapAPYWorkerError.paginationLimit
    }

    // MARK: - Validation

    static func isAllowedEndpoint(_ url: URL) -> Bool {
        guard
            url.scheme?.lowercased() == "https",
            let host = url.host?.lowercased(),
            Constants.allowedHosts.contains(host),
            url.user == nil,
            url.password == nil,
            url.port == nil,
            url.query == nil,
            url.fragment == nil
        else {
            return false
        }

        return true
    }

    static func isValidIdentifier(_ identifier: String) -> Bool {
        guard
            !identifier.isEmpty,
            identifier.utf8.count <= Constants.maximumIdentifierBytes
        else {
            return false
        }

        return identifier.unicodeScalars.allSatisfy { scalar in
            switch scalar {
            case "0" ... "9", "a" ... "z", "A" ... "Z", "-":
                return true
            default:
                return false
            }
        }
    }

    /// A missing, malformed, negative or implausible value is shown as "no APY" for that pool
    /// rather than failing the whole list.
    static func validatedApy(_ text: String?) -> Decimal? {
        guard
            let text,
            !text.isEmpty,
            text.utf8.count <= Constants.maximumValueBytes,
            text.unicodeScalars.allSatisfy({ scalar in
                switch scalar {
                case "0" ... "9", ".", "-", "+", "e", "E":
                    return true
                default:
                    return false
                }
            }),
            let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
            value.isFinite,
            !value.isNaN,
            value >= 0,
            value <= Constants.maximumApy
        else {
            return nil
        }

        return value
    }

    // MARK: - Networking

    private func loadPage(after cursor: String?) async throws -> Page {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                operationName: Constants.operationName,
                query: Constants.query,
                variables: RequestBody.Variables(first: Constants.pageSize, after: cursor)
            )
        )

        let (data, response) = try await perform(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolkaswapAPYWorkerError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw PolkaswapAPYWorkerError.invalidStatusCode(httpResponse.statusCode)
        }

        guard data.count <= Constants.maximumResponseBytes else {
            throw PolkaswapAPYWorkerError.responseTooLarge
        }

        let decoded: ResponseBody
        do {
            decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        } catch {
            throw PolkaswapAPYWorkerError.invalidResponse
        }

        if let errors = decoded.errors, !errors.isEmpty {
            throw PolkaswapAPYWorkerError.indexerError
        }

        guard let entities = decoded.data?.entities else {
            throw PolkaswapAPYWorkerError.invalidResponse
        }

        return entities
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let taskBox = DataTaskBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: request) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let data, let response else {
                        continuation.resume(throwing: PolkaswapAPYWorkerError.invalidResponse)
                        return
                    }

                    continuation.resume(returning: (data, response))
                }

                taskBox.set(task)
                task.resume()
            }
        } onCancel: {
            taskBox.cancel()
        }
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = true
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false

        return URLSession(
            configuration: configuration,
            delegate: PolkaswapAPYRedirectRejectingDelegate(),
            delegateQueue: nil
        )
    }
}

// MARK: - Wire format

private struct RequestBody: Encodable {
    struct Variables: Encodable {
        let first: Int
        let after: String?

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(first, forKey: .first)
            if let after {
                try container.encode(after, forKey: .after)
            } else {
                try container.encodeNil(forKey: .after)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case first
            case after
        }
    }

    let operationName: String
    let query: String
    let variables: Variables
}

private struct ResponseBody: Decodable {
    struct DataBody: Decodable {
        let entities: Page?
    }

    struct GraphQLError: Decodable {
        let message: String?
    }

    let data: DataBody?
    let errors: [GraphQLError]?
}

private struct Page: Decodable {
    struct PageInfo: Decodable {
        let hasNextPage: Bool?
        let endCursor: String?
    }

    let nodes: [Node]
    let pageInfo: PageInfo
}

private struct Node: Decodable {
    let id: String
    let strategicBonusApy: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case strategicBonusApy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)

        if let text = try? container.decodeIfPresent(String.self, forKey: .strategicBonusApy) {
            strategicBonusApy = text
        } else if let number = try? container.decodeIfPresent(Decimal.self, forKey: .strategicBonusApy) {
            strategicBonusApy = NSDecimalNumber(decimal: number).stringValue
        } else {
            strategicBonusApy = nil
        }
    }
}

// MARK: - Helpers

private final class DataTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var isCancelled = false

    func set(_ task: URLSessionDataTask) {
        lock.lock()
        self.task = task
        let cancelled = isCancelled
        lock.unlock()

        if cancelled {
            task.cancel()
        }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let task = self.task
        lock.unlock()

        task?.cancel()
    }
}

private final class PolkaswapAPYRedirectRejectingDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
