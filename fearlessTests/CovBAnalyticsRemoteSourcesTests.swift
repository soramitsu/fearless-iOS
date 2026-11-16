import XCTest
import RobinHood
import SSFModels
import SSFUtils
@testable import fearless

/// The analytics screens read stake history and rewards from the chain's staking indexer. A refused local port answers
/// every request at once, so these tests follow the failure path without any outside network.
enum CovBArFixtures {
    static let refusedURL = "https://127.0.0.1:9/"

    static func chainAsset() throws -> ChainAsset {
        let staking = try XCTUnwrap(ChainModel.BlockExplorer(type: "subquery", url: try XCTUnwrap(URL(string: refusedURL))))
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: "covb-ar-" + UUID().uuidString,
            paraId: nil,
            name: "Covbnet",
            xcm: nil,
            nodes: [],
            addressPrefix: 42,
            icon: nil,
            externalApi: ChainModel.ExternalApiSet(staking: staking),
            iosMinAppVersion: nil,
            identityChain: nil
        )
        return ChainAsset(chain: chain, asset: CovBAnFixtures.asset())
    }
}

final class CovBArRemoteSourcesTests: XCTestCase {
    func testStakeHistoryRequestFailureReachesThePresenter() throws {
        let output = CovBAnStakeOutputStub()
        let interactor = AnalyticsStakeInteractor(
            stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryStub(),
            operationManager: OperationManager(),
            selectedAccountAddress: "account",
            chainAsset: try CovBArFixtures.chainAsset()
        )
        interactor.presenter = output

        interactor.fetchStakeHistory(stashAddress: "stash")

        XCTAssertTrue(CovBAnFixtures.spin(timeout: 30) { !output.stakeResults.isEmpty })
        XCTAssertThrowsError(try output.stakeResults.first?.get())
    }

    func testRewardsRequestFailureReachesTheStrategyOutput() throws {
        let output = CovBAnRewardsStrategyOutputStub()
        let strategy = AnalyticsRewardsRelaychainStrategy(
            stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryStub(),
            operationManager: OperationManager(),
            logger: nil,
            chainAsset: try CovBArFixtures.chainAsset(),
            wallet: CovBAnFixtures.wallet(),
            output: output
        )

        strategy.fetchRewards(address: "stash")

        XCTAssertTrue(CovBAnFixtures.spin(timeout: 30) { !output.errors.isEmpty })
        XCTAssertTrue(output.subqueryData.isEmpty)
    }

    func testValidatorsReloadRequestsTheNominatedEraRangeAndReportsFailures() throws {
        let chainAsset = try CovBArFixtures.chainAsset()
        let stash = try AddressFactory.address(for: Data(repeating: 0x44, count: 32), chain: chainAsset.chain)
        let nomination = try CovBAnFixtures.nomination(targets: [Data(repeating: 0x55, count: 32)], submittedIn: 3)
        let output = CovBAnValidatorsOutputStub()
        let operationManager = OperationManager()
        let interactor = AnalyticsValidatorsInteractor(
            substrateProviderFactory: SubstrateDataProviderFactory(facade: SubstrateStorageTestFacade(), operationManager: operationManager),
            stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryStub(),
            identityOperationFactory: CovBAnIdentityFactoryStub(result: .success([:])),
            operationManager: operationManager,
            engine: MockConnection(),
            runtimeService: CovBVmPlainRuntime(),
            storageRequestFactory: StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: operationManager),
            chainAsset: chainAsset,
            selectedAccount: CovBAnFixtures.wallet()
        )
        interactor.presenter = output

        interactor.handleStashItem(result: .success(StashItem(stash: stash, controller: stash)), for: stash)
        interactor.handleNomination(result: .success(nomination), accountId: Data(), chainId: chainAsset.chain.chainId)
        interactor.handleCurrentEra(result: .success(9), chainId: chainAsset.chain.chainId)

        XCTAssertTrue(CovBAnFixtures.spin(timeout: 30) { !output.eraRanges.isEmpty && !output.eraInfos.isEmpty && !output.rewards.isEmpty })
        XCTAssertEqual(output.eraRanges.last?.start, 4)
        XCTAssertEqual(output.eraRanges.last?.end, 9)
        XCTAssertThrowsError(try output.eraInfos.first?.get())
        XCTAssertThrowsError(try output.rewards.first?.get())
    }
}
