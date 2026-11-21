import XCTest
import RobinHood
import SSFModels
@testable import fearless

/// getPossibleChains queued its chain fetch before setting the fetch's completion block. A fetch that finished in
/// between never resumed the caller, so the Send screen waited forever for the chains an address can belong to.
final class AddressChainDefinerCompletionTests: XCTestCase {
    func testAFetchThatFinishesBeforeTheCallerWaitsStillAnswers() async {
        let repository = ChainRepositoryFactory(storageFacade: SubstrateStorageTestFacade()).createRepository()
        let definer = AddressChainDefiner(
            // Runs the fetch as soon as it is queued, the fastest a fetch can finish.
            operationManager: InlineOperationManager(),
            chainModelRepository: AnyDataProviderRepository(repository),
            wallet: AccountGenerator.generateMetaAccount()
        )

        let answered = expectation(description: "possible chains answered")
        let result = PossibleChainsBox()
        Task {
            result.chains = await definer.getPossibleChains(for: "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY")
            answered.fulfill()
        }
        await fulfillment(of: [answered], timeout: 5)

        XCTAssertEqual(result.chains?.count, 0, "an empty chain store answers with no chains")
    }
}

private final class PossibleChainsBox {
    var chains: [ChainModel]?
}
