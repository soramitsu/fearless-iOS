import XCTest
@testable import fearless

/// The Bitcoin indexer client bounds every request, so a service that accepts no connection fails over to the next
/// one in seconds instead of after URLSession's 60 s default (the BTC row stayed at 0 for minutes while
/// mempool.space did not answer). Requests go to an injected transport or a URL protocol stub, never the network.
final class BitcoinIndexerRequestTimeoutTests: XCTestCase {
    private static let mainnetAddress = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"

    override func tearDown() {
        BitcoinIndexerHangingPrimaryURLProtocol.reset()
        super.tearDown()
    }

    func testEveryRequestCarriesTheBoundedTimeout() async throws {
        XCTAssertGreaterThanOrEqual(BitcoinIndexerClient.requestTimeout, 15)
        XCTAssertLessThanOrEqual(BitcoinIndexerClient.requestTimeout, 20)

        let transport = BitcoinIndexerRecordingTransport()
        let client = BitcoinIndexerClient(transport: transport)

        transport.responses = [Self.addressJSON, Data(#"{"1":12.5}"#.utf8), Data(String(repeating: "ab", count: 32).utf8)]
        _ = try await client.address(address: Self.mainnetAddress, network: .mainnet, baseURL: nil)
        _ = try await client.feeEstimates(network: .mainnet, baseURL: nil)
        _ = try await client.broadcastTransaction(txHex: "00aa", network: .mainnet, baseURL: nil)

        XCTAssertEqual(transport.requests.map(\.timeoutInterval), Array(repeating: BitcoinIndexerClient.requestTimeout, count: 3))
        XCTAssertEqual(transport.requests.map(\.url?.host), ["blockstream.info", "blockstream.info", "blockstream.info"])
    }

    func testAHangingPrimaryFailsOverToTheFallbackWithinTheBound() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BitcoinIndexerHangingPrimaryURLProtocol.self]
        let transport = URLSessionUniversalWalletHTTPTransport(session: URLSession(configuration: configuration))
        let bound: TimeInterval = 1
        let client = BitcoinFailoverIndexerClient(
            client: BitcoinIndexerClient(transport: transport, requestTimeout: bound),
            health: BitcoinIndexerEndpointHealth()
        )

        let started = Date()
        let fees = try await client.feeEstimates(network: .mainnet, baseURL: nil)
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertEqual(fees["1"], 12.5, "The fallback's answer")
        XCTAssertEqual(BitcoinIndexerHangingPrimaryURLProtocol.hosts, ["blockstream.info", "mempool.space"])
        XCTAssertGreaterThanOrEqual(elapsed, bound * 0.8, "The primary was given its bound")
        XCTAssertLessThan(elapsed, bound + 10, "The hanging primary fails over within its bound, not after 60 s")
    }

    private static let addressJSON = Data(
        """
        {"address":"\(mainnetAddress)",
         "chain_stats":{"funded_txo_count":0,"funded_txo_sum":0,"spent_txo_count":0,"spent_txo_sum":0,"tx_count":0},
         "mempool_stats":{"funded_txo_count":0,"funded_txo_sum":0,"spent_txo_count":0,"spent_txo_sum":0,"tx_count":0}}
        """.utf8
    )
}

private final class BitcoinIndexerRecordingTransport: UniversalWalletHTTPTransport {
    var responses: [Data] = []
    private(set) var requests: [URLRequest] = []

    func perform(_ request: URLRequest) async throws -> Data {
        requests.append(request)
        return responses.isEmpty ? Data() : responses.removeFirst()
    }
}

/// blockstream.info accepts the request and never answers (like a service that takes no connection); mempool.space
/// answers at once. A safety timer fails a hung request after 30 s, so a broken bound fails the test instead of
/// hanging the run.
private final class BitcoinIndexerHangingPrimaryURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var recordedHosts: [String] = []
    private var safetyTimer: DispatchWorkItem?

    static var hosts: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedHosts
    }

    static func reset() {
        lock.lock()
        recordedHosts = []
        lock.unlock()
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let host = request.url?.host ?? ""
        Self.lock.lock()
        Self.recordedHosts.append(host)
        Self.lock.unlock()

        guard host == "mempool.space", let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil) else {
            let timer = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            }
            safetyTimer = timer
            DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timer)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"1":12.5}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        safetyTimer?.cancel()
        safetyTimer = nil
    }
}
