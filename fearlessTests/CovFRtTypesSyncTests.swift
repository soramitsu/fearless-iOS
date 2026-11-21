import RobinHood
import SSFUtils
import XCTest
@testable import fearless

final class CovFRtTypesSyncTests: XCTestCase {
    private var directory: String = ""

    override func setUpWithError() throws {
        directory = (NSTemporaryDirectory() as NSString).appendingPathComponent("covf-types-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: directory)
    }

    func testSyncPublishesVersionedTypesAndStoresThemOnDisk() throws {
        let payload: [[String: Any]] = [["chainId": "aa", "types": ["A": "u8"]], ["chainId": "bb", "types": [:]]]
        let fetcher = CovFRtDataFetcher(results: [.success(try JSONSerialization.data(withJSONObject: payload))])
        let events = CovFBalEventCenter()
        let notified = expectation(description: "event")
        events.onNotify = { _ in notified.fulfill() }
        let files = RuntimeFilesOperationFactory(repository: FileRepository(), directoryPath: directory)
        let service = makeService(fetcher: fetcher, files: files, events: events, retry: CovFRtRetry(delays: [:]))
        service.syncUp()
        wait(for: [notified], timeout: 5)
        let event = try XCTUnwrap(events.events.first as? RuntimeChainsTypesSyncCompleted)
        XCTAssertEqual(Set(event.versioningMap.keys), ["aa", "bb"])
        let stored = try JSONSerialization.jsonObject(with: XCTUnwrap(event.versioningMap["aa"])) as? [String: Any]
        XCTAssertEqual(stored?["chainId"] as? String, "aa")
        XCTAssertEqual(fetcher.requestedURLs, [URL(string: "https://types.invalid/chains.json")])

        let path = (directory as NSString).appendingPathComponent("chains-types")
        let saved = try covFRtWaitForFile(path) { (try? JSONDecoder().decode([String: Data].self, from: $0)) != nil }
        let decoded = try JSONDecoder().decode([String: Data].self, from: saved)
        XCTAssertEqual(decoded, event.versioningMap)

        let readWrapper = files.fetchChainsTypesOperation()
        XCTAssertEqual(try CovFFixtures.execute(readWrapper), saved)
    }

    func testFailureRetriesWithStrategyDelayThenSucceeds() throws {
        let error = NSError(domain: "types", code: 3)
        let payload = try JSONSerialization.data(withJSONObject: [["chainId": "cc"]])
        let fetcher = CovFRtDataFetcher(results: [.failure(error), .success(payload)])
        let events = CovFBalEventCenter()
        let logger = CovFBalLogger()
        let notified = expectation(description: "event after retry")
        events.onNotify = { _ in notified.fulfill() }
        let retry = CovFRtRetry(delays: [1: 0.01])
        let service = makeService(fetcher: fetcher, events: events, retry: retry, logger: logger)
        service.syncUp()
        wait(for: [notified], timeout: 5)
        XCTAssertEqual(fetcher.requestedURLs.count, 2)
        XCTAssertEqual(retry.attempts, [1])
        XCTAssertEqual(logger.errors, [error.localizedDescription])
        XCTAssertEqual((events.events.first as? RuntimeChainsTypesSyncCompleted)?.versioningMap.keys.first, "cc")
    }

    func testMissingResultCountsAsFailureAndStopsWhenStrategyGivesUp() {
        let fetcher = CovFRtDataFetcher(results: [nil])
        let logger = CovFBalLogger()
        let failed = expectation(description: "failure logged")
        logger.onError = { _ in failed.fulfill() }
        let retry = CovFRtRetry(delays: [:])
        let events = CovFBalEventCenter()
        let service = makeService(fetcher: fetcher, events: events, retry: retry, logger: logger)
        service.syncUp()
        wait(for: [failed], timeout: 5)
        logger.onError = nil
        XCTAssertEqual(retry.attempts, [1])
        XCTAssertTrue(events.events.isEmpty)
        XCTAssertEqual(logger.errors.count, 1)
    }

    func testPayloadWithoutChainIdOrNotAnArrayIsLoggedWithoutEvent() throws {
        for payload in [try JSONSerialization.data(withJSONObject: [["types": [:]]]), Data(#"{"chainId":"aa"}"#.utf8)] {
            let fetcher = CovFRtDataFetcher(results: [.success(payload)])
            let logger = CovFBalLogger()
            let logged = expectation(description: "decode error")
            logger.onError = { _ in logged.fulfill() }
            let events = CovFBalEventCenter()
            let service = makeService(fetcher: fetcher, events: events, retry: CovFRtRetry(delays: [:]), logger: logger)
            service.syncUp()
            wait(for: [logged], timeout: 5)
            logger.onError = nil
            XCTAssertTrue(events.events.isEmpty)
            XCTAssertEqual(fetcher.requestedURLs.count, 1)
        }
    }

    func testSyncUpAfterFailureCancelsPendingRetryAndFetchesAgain() throws {
        let error = NSError(domain: "types", code: 4)
        let payload = try JSONSerialization.data(withJSONObject: [["chainId": "dd"]])
        let fetcher = CovFRtDataFetcher(results: [.failure(error), .success(payload)])
        let logger = CovFBalLogger()
        let failed = expectation(description: "first failure")
        logger.onError = { _ in failed.fulfill() }
        let events = CovFBalEventCenter()
        let retry = CovFRtRetry(delays: [1: 60])
        let service = makeService(fetcher: fetcher, events: events, retry: retry, logger: logger)
        service.syncUp()
        wait(for: [failed], timeout: 5)
        logger.onError = nil
        let notified = expectation(description: "manual retry")
        events.onNotify = { _ in notified.fulfill() }
        service.syncUp()
        wait(for: [notified], timeout: 5)
        XCTAssertEqual(fetcher.requestedURLs.count, 2)
        XCTAssertEqual(events.events.count, 1)
    }

    func testRuntimeFilesFactoryReadsAndWritesCommonAndChainFiles() throws {
        let files = RuntimeFilesOperationFactory(repository: FileRepository(), directoryPath: directory)
        XCTAssertNil(try CovFFixtures.execute(files.fetchCommonTypesOperation()))
        try CovFFixtures.execute(files.saveCommonTypesOperation { Data("common".utf8) })
        try CovFFixtures.execute(files.saveChainTypesOperation(for: "chain") { Data("chain".utf8) })
        XCTAssertEqual(try CovFFixtures.execute(files.fetchCommonTypesOperation()), Data("common".utf8))
        XCTAssertEqual(try CovFFixtures.execute(files.fetchChainTypesOperation(for: "chain")), Data("chain".utf8))
        XCTAssertNil(try CovFFixtures.execute(files.fetchChainTypesOperation(for: "other")))
        XCTAssertTrue(FileManager.default.fileExists(atPath: (directory as NSString).appendingPathComponent("chain-types")))
    }

    private func makeService(
        fetcher: CovFRtDataFetcher,
        files: RuntimeFilesOperationFactoryProtocol? = nil,
        events: CovFBalEventCenter,
        retry: CovFRtRetry,
        logger: CovFBalLogger = CovFBalLogger()
    ) -> ChainsTypesSyncService {
        ChainsTypesSyncService(
            url: URL(string: "https://types.invalid/chains.json"),
            filesOperationFactory: files ?? RuntimeFilesOperationFactory(repository: FileRepository(), directoryPath: directory),
            dataOperationFactory: fetcher,
            eventCenter: events,
            operationQueue: OperationQueue(),
            retryStrategy: retry,
            logger: logger
        )
    }
}

func covFRtWaitForFile(_ path: String, timeout: TimeInterval = 5, isComplete: (Data) -> Bool = { _ in true }) throws -> Data {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if let data = FileManager.default.contents(atPath: path), isComplete(data) { return data }
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
    throw NSError(domain: "covf.file", code: 1, userInfo: [NSLocalizedDescriptionKey: "No file at \(path)"])
}

final class CovFRtDataFetcher: DataOperationFactoryProtocol {
    private let lock = NSLock()
    private var results: [Result<Data, Error>?]
    private var urls: [URL] = []

    init(results: [Result<Data, Error>?]) { self.results = results }

    var requestedURLs: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }

    func fetchData(from url: URL) -> BaseOperation<Data> {
        lock.lock()
        urls.append(url)
        let next = results.isEmpty ? nil : results.removeFirst()
        lock.unlock()
        let operation = BaseOperation<Data>()
        operation.result = next
        return operation
    }
}

final class CovFRtRetry: ReconnectionStrategyProtocol {
    private let lock = NSLock()
    private let delays: [Int: TimeInterval]
    private var storedAttempts: [Int] = []

    init(delays: [Int: TimeInterval]) { self.delays = delays }

    var attempts: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return storedAttempts
    }

    func reconnectAfter(attempt: Int) -> TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        storedAttempts.append(attempt)
        return delays[attempt]
    }
}
