import RobinHood
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
    func testStoredScamEntryIsReturned() async throws {
        let entry = ScamInfo(name: "Thief", address: "addr", type: .theft, subtype: "t")
        let fetcher = makeFetcher(entries: [entry])
        let result = try await fetcher.fetch(address: "addr", chain: covFMiscChain(id: "1"))
        XCTAssertEqual(result, entry)
    }

    /// Ethereum, BNB Smart Chain and Polygon once fell back to a third-party wallet score; every chain now
    /// answers from the stored scam list alone.
    func testAddressMissingFromTheListGivesNoWarningOnEveryChain() async throws {
        let fetcher = makeFetcher(entries: [ScamInfo(name: "Other", address: "other", type: .scam, subtype: "")])
        for chainId in ["1", "56", "137", "2"] {
            let result = try await fetcher.fetch(address: "addr", chain: covFMiscChain(id: chainId))
            XCTAssertNil(result, chainId)
        }
    }

    func testRepositoryFailureGivesNoWarning() async throws {
        let repository = CovFRepository<ScamInfo>()
        repository.failure = NSError(domain: "scam", code: 2)
        let fetcher = ScamInfoFetcher(
            scamServiceOperationFactory: ScamServiceOperationFactory(repository: AnyDataProviderRepository(repository))
        )
        let result = try await fetcher.fetch(address: "addr", chain: covFMiscChain(id: "56"))
        XCTAssertNil(result)
    }

    func testOperationFactoryReadsAllEntries() throws {
        let entries = [ScamInfo(name: "A", address: "a", type: .scam, subtype: ""), ScamInfo(name: "B", address: "b", type: .service, subtype: "")]
        let factory = ScamServiceOperationFactory(repository: AnyDataProviderRepository(CovFRepository<ScamInfo>(entries)))
        let operation = factory.fetchAllOperations()
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        XCTAssertEqual(try XCTUnwrap(operation.result).get(), entries)
    }

    private func makeFetcher(entries: [ScamInfo]) -> ScamInfoFetcher {
        ScamInfoFetcher(
            scamServiceOperationFactory: ScamServiceOperationFactory(repository: AnyDataProviderRepository(CovFRepository<ScamInfo>(entries)))
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
