import XCTest
import RobinHood
import SoraFoundation
@testable import fearless

/// A Nomis answer without a score (no `data`, or `data` without `score`) was read as score 0, so the Send screen
/// warned "low network activity" about an address Nomis had not rated. The account score view already shows such an
/// answer as "no score"; the warning now treats it the same way. An explicit low score still warns.
final class ScamInfoMissingNomisScoreTests: XCTestCase {
    private let nomisChain = covFMiscChain(id: "137")

    func testAnAnswerWithoutAScoreGivesNoWarning() async throws {
        for json in ["{}", "{\"data\":null}", "{\"data\":{\"address\":\"addr\"}}", "{\"data\":{\"score\":null}}"] {
            let fetcher = makeFetcher(statistics: JSONStatistics(json: json))
            let result = try await fetcher.fetch(address: "addr", chain: nomisChain)
            XCTAssertNil(result, json)
        }
    }

    func testNoAnswerGivesNoWarning() async throws {
        let fetcher = makeFetcher(statistics: JSONStatistics(json: nil))
        let result = try await fetcher.fetch(address: "addr", chain: nomisChain)
        XCTAssertNil(result)
    }

    func testAScoreOfZeroStillWarns() async throws {
        let fetcher = makeFetcher(statistics: JSONStatistics(json: "{\"data\":{\"score\":0}}"))
        let result = try await fetcher.fetch(address: "addr", chain: nomisChain)
        XCTAssertEqual(result?.type, .lowScore)
    }

    private func makeFetcher(statistics: AccountStatisticsFetching) -> ScamInfoFetcher {
        ScamInfoFetcher(
            scamServiceOperationFactory: ScamServiceOperationFactory(
                repository: AnyDataProviderRepository(CovFRepository<ScamInfo>())
            ),
            accountScoreFetching: statistics,
            localizationManager: LocalizationManager.shared
        )
    }
}

private final class JSONStatistics: AccountStatisticsFetching {
    private let json: String?

    init(json: String?) {
        self.json = json
    }

    func subscribeForStatistics(address _: String) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? {
        guard let json else {
            return nil
        }
        return try JSONDecoder().decode(AccountStatisticsResponse.self, from: Data(json.utf8))
    }
}
