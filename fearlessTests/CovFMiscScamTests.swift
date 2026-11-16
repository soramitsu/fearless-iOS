import RobinHood
import SoraFoundation
import SSFModels
import XCTest
@testable import fearless

final class CovFMiscScamSyncTests: XCTestCase {
    private let header = "name,address,type,subtype"

    func testSyncReplacesChangedRowsAddsNewOnesAndRemovesMissing() throws {
        let repository = CovFRepository<ScamInfo>([
            ScamInfo(name: "Old", address: "a", type: .scam, subtype: "x"),
            ScamInfo(name: "Gone", address: "b", type: .theft, subtype: "y")
        ])
        let csv = [header, "New,a,scam,x", "\"Quoted, Name\",c,exchange,z"].joined(separator: "\n")
        let fetcher = CovFRtDataFetcher(results: [.success(Data(csv.utf8))])
        let service = makeService(repository: repository, fetcher: fetcher, retry: CovFRtRetry(delays: [:]))
        service.syncUp()
        try covFMiscEventually { Set(repository.items.map(\.address)) == ["a", "c"] }
        let byAddress = Dictionary(uniqueKeysWithValues: repository.items.map { ($0.address, $0) })
        XCTAssertEqual(byAddress["a"]?.name, "New")
        XCTAssertEqual(byAddress["c"]?.name, "Quoted, Name")
        XCTAssertEqual(byAddress["c"]?.type, .exchange)
        XCTAssertEqual(fetcher.requestedURLs, [URL(string: "https://scam.invalid/list.csv")])
    }

    func testEmptyDownloadKeepsStoredFlagsAndRetriesUntilListArrives() throws {
        let stored = ScamInfo(name: "Kept", address: "k", type: .scam, subtype: "s")
        let repository = CovFRepository<ScamInfo>([stored])
        let csv = [header, "Next,n,donation,d"].joined(separator: "\n")
        let fetcher = CovFRtDataFetcher(results: [.success(Data(header.utf8)), .success(Data(csv.utf8))])
        let retry = CovFRtRetry(delays: [0: 0.01])
        let service = makeService(repository: repository, fetcher: fetcher, retry: retry)
        service.syncUp()
        try covFMiscEventually { repository.items.map(\.address) == ["n"] }
        XCTAssertEqual(fetcher.requestedURLs.count, 2)
        XCTAssertEqual(retry.attempts, [0])
    }

    func testLocalOrRemoteFailureIsRetriedOnlyWhileStrategyAllows() throws {
        let repository = CovFRepository<ScamInfo>([ScamInfo(name: "Kept", address: "k", type: .scam, subtype: "s")])
        repository.failure = NSError(domain: "scam", code: 1)
        let fetcher = CovFRtDataFetcher(results: [.failure(NSError(domain: "remote", code: 2))])
        let retry = CovFRtRetry(delays: [:])
        let service = makeService(repository: repository, fetcher: fetcher, retry: retry)
        service.syncUp()
        try covFMiscEventually { retry.attempts == [0] }
        XCTAssertEqual(repository.items.map(\.address), ["k"])
        XCTAssertEqual(fetcher.requestedURLs.count, 1)
    }

    func testMissingListURLDoesNothing() {
        let fetcher = CovFRtDataFetcher(results: [])
        let service = ScamSyncService(scamListCsvURL: nil, repository: AnyDataProviderRepository(CovFRepository<ScamInfo>()),
                                      dataFetchFactory: fetcher, retryStrategy: CovFRtRetry(delays: [:]), operationQueue: OperationQueue())
        service.syncUp()
        XCTAssertTrue(fetcher.requestedURLs.isEmpty)
    }

    private func makeService(repository: CovFRepository<ScamInfo>, fetcher: CovFRtDataFetcher, retry: CovFRtRetry) -> ScamSyncService {
        ScamSyncService(scamListCsvURL: URL(string: "https://scam.invalid/list.csv"), repository: AnyDataProviderRepository(repository),
                        dataFetchFactory: fetcher, retryStrategy: retry, operationQueue: OperationQueue())
    }
}

final class CovFMiscScamInfoFetcherTests: XCTestCase {
    func testStoredScamEntryWinsWithoutAskingForScore() async throws {
        let entry = ScamInfo(name: "Thief", address: "addr", type: .theft, subtype: "t")
        let statistics = CovFMiscStatistics(score: 0.0)
        let fetcher = makeFetcher(entries: [entry], statistics: statistics)
        let result = try await fetcher.fetch(address: "addr", chain: covFMiscChain(id: "1"))
        XCTAssertEqual(result, entry)
        XCTAssertTrue(statistics.addresses.isEmpty)
    }

    func testLowNomisScoreProducesLowScoreWarningOnSupportedChainsOnly() async throws {
        let statistics = CovFMiscStatistics(score: 0.1)
        let fetcher = makeFetcher(entries: [], statistics: statistics)
        let unsupported = try await fetcher.fetch(address: "addr", chain: covFMiscChain(id: "2"))
        XCTAssertNil(unsupported)
        XCTAssertTrue(statistics.addresses.isEmpty)
        let warning = try await fetcher.fetch(address: "addr", chain: covFMiscChain(id: "137"))
        XCTAssertEqual(warning?.type, .lowScore)
        XCTAssertEqual(warning?.address, "addr")
        XCTAssertEqual(warning?.name, R.string.localizable.scamInfoNomisName(preferredLanguages: fetcher.selectedLocale.rLanguages))
        XCTAssertEqual(statistics.addresses, ["addr"])
    }

    func testHighScoreAndFailuresProduceNoWarning() async throws {
        for statistics in [CovFMiscStatistics(score: 0.9), CovFMiscStatistics(error: NSError(domain: "nomis", code: 1))] {
            let repository = CovFRepository<ScamInfo>()
            repository.failure = NSError(domain: "scam", code: 2)
            let fetcher = ScamInfoFetcher(
                scamServiceOperationFactory: ScamServiceOperationFactory(repository: AnyDataProviderRepository(repository)),
                accountScoreFetching: statistics,
                localizationManager: LocalizationManager.shared
            )
            let result = try await fetcher.fetch(address: "addr", chain: covFMiscChain(id: "56"))
            XCTAssertNil(result)
            XCTAssertEqual(statistics.addresses, ["addr"])
        }
    }

    func testOperationFactoryReadsAllEntries() throws {
        let entries = [ScamInfo(name: "A", address: "a", type: .scam, subtype: ""), ScamInfo(name: "B", address: "b", type: .service, subtype: "")]
        let factory = ScamServiceOperationFactory(repository: AnyDataProviderRepository(CovFRepository<ScamInfo>(entries)))
        let operation = factory.fetchAllOperations()
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        XCTAssertEqual(try XCTUnwrap(operation.result).get(), entries)
    }

    private func makeFetcher(entries: [ScamInfo], statistics: CovFMiscStatistics) -> ScamInfoFetcher {
        ScamInfoFetcher(
            scamServiceOperationFactory: ScamServiceOperationFactory(repository: AnyDataProviderRepository(CovFRepository<ScamInfo>(entries))),
            accountScoreFetching: statistics,
            localizationManager: LocalizationManager.shared
        )
    }
}

func covFMiscChain(id: String, assetIds: [String] = []) -> ChainModel {
    let assets = assetIds.map {
        AssetModel(id: $0, name: "Asset \($0)", symbol: "A\($0)", precision: 2, currencyId: nil, isUtility: false, isNative: false)
    }
    return ChainModel(
        rank: nil, disabled: false, chainId: id, parentId: nil, paraId: nil, name: "Chain \(id)", assets: Set(assets), xcm: nil,
        nodes: [], addressPrefix: 42, icon: nil, options: nil, iosMinAppVersion: nil, identityChain: nil
    )
}

func covFMiscEventually(timeout: TimeInterval = 5, _ condition: () -> Bool) throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return }
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
    if condition() { return }
    throw NSError(domain: "covf.eventually", code: 1, userInfo: [NSLocalizedDescriptionKey: "Condition not met in \(timeout) s"])
}

final class CovFMiscStatistics: AccountStatisticsFetching {
    private let lock = NSLock()
    private let score: Decimal?
    private let error: Error?
    private var storedAddresses: [String] = []

    init(score: Decimal) {
        self.score = score
        error = nil
    }

    init(error: Error) {
        score = nil
        self.error = error
    }

    var addresses: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedAddresses
    }

    func subscribeForStatistics(address _: String) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func fetchStatistics(address: String) async throws -> AccountStatisticsResponse? {
        lock.lock()
        storedAddresses.append(address)
        lock.unlock()
        if let error { throw error }
        let json: [String: Any] = ["data": ["score": NSDecimalNumber(decimal: score ?? .zero)]]
        return try JSONDecoder().decode(AccountStatisticsResponse.self, from: JSONSerialization.data(withJSONObject: json))
    }
}
