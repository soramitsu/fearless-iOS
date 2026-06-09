import Foundation

public enum FireMockHTTPMethod {
    case get
    case post
    case put
    case delete
}

public protocol FireMockProtocol {
    var bundle: Bundle { get }
    var afterTime: TimeInterval { get }
    var statusCode: Int { get }
    func mockFile() -> String
}

public extension FireMockProtocol {
    var bundle: Bundle { .main }
    var afterTime: TimeInterval { 0 }
    var statusCode: Int { 200 }
}

public enum FireMock {
    public private(set) static var isEnabled = false

    public static func enabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    public static func register(mock: FireMockProtocol, forURL url: URL, httpMethod: FireMockHTTPMethod) {
        FireURLProtocol.register(mock: mock, for: url, method: httpMethod)
    }

    public static func unregisterAll() {
        FireURLProtocol.unregisterAll()
    }
}

public final class FireURLProtocol: URLProtocol {
    private struct Key: Hashable {
        let url: URL
        let method: String
    }

    private static var mocks: [Key: FireMockProtocol] = [:]
    private static let lock = NSLock()

    public static func register(mock: FireMockProtocol, for url: URL, method: FireMockHTTPMethod) {
        lock.lock()
        defer { lock.unlock() }
        mocks[Key(url: url, method: method.urlMethod)] = mock
    }

    public static func unregisterAll() {
        lock.lock()
        defer { lock.unlock() }
        mocks.removeAll()
    }

    override public class func canInit(with request: URLRequest) -> Bool {
        guard FireMock.isEnabled, let url = request.url else {
            return false
        }

        return mock(for: url, method: request.httpMethod ?? "GET") != nil
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override public func startLoading() {
        guard
            let url = request.url,
            let mock = Self.mock(for: url, method: request.httpMethod ?? "GET")
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + mock.afterTime) {
            do {
                let data = try Self.data(for: mock)
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: mock.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )!

                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: data)
                self.client?.urlProtocolDidFinishLoading(self)
            } catch {
                self.client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override public func stopLoading() {}

    private static func mock(for url: URL, method: String) -> FireMockProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return mocks[Key(url: url, method: method.uppercased())]
    }

    private static func data(for mock: FireMockProtocol) throws -> Data {
        let file = mock.mockFile()
        let nsFile = file as NSString
        let name = nsFile.deletingPathExtension
        let ext = nsFile.pathExtension.isEmpty ? nil : nsFile.pathExtension

        guard let url = mock.bundle.url(forResource: name, withExtension: ext) else {
            throw URLError(.fileDoesNotExist)
        }

        return try Data(contentsOf: url)
    }
}

public extension URLSessionConfiguration {
    static let classInit: Void = {
        URLProtocol.registerClass(FireURLProtocol.self)
    }()
}

private extension FireMockHTTPMethod {
    var urlMethod: String {
        switch self {
        case .get:
            return "GET"
        case .post:
            return "POST"
        case .put:
            return "PUT"
        case .delete:
            return "DELETE"
        }
    }
}
