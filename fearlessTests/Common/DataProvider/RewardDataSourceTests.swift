import XCTest
@testable import fearless
import RobinHood

class RewardDataSourceTests: NetworkBaseTests {

    func testCorrectSyncAfterMultipleUpdates() {
        do {
            // given

            let storageFacade = SubstrateStorageTestFacade()
            let url = WalletAssetId.westend.subscanUrl?
                .appendingPathComponent(SubscanApi.rewardsAndSlashes)
            TotalRewardMock.register(mock: .westendFirst, url: url!)

            let expectedRewardAfterFirst: Decimal = 1.0
            let expectedRewardAfterSecond: Decimal = 3.0

            // when

            let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
                storageFacade.createRepository()

            let rewardAfterFirstCall = try performRewardRequest(for: AnyDataProviderRepository(repository),
                                                                address: WestendStub.address,
                                                                assetId: .westend,
                                                                chain: .westend)

            // then

            XCTAssertEqual(rewardAfterFirstCall?.amount.decimalValue, expectedRewardAfterFirst)

            TotalRewardMock.register(mock: .westendSecond, url: url!)

            let rewardAfterSecondCall = try performRewardRequest(for: AnyDataProviderRepository(repository),
                                                                 address: WestendStub.address,
                                                                 assetId: .westend,
                                                                 chain: .westend)

            XCTAssertEqual(rewardAfterSecondCall?.amount.decimalValue, expectedRewardAfterSecond)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func performRewardRequest(for repository: AnyDataProviderRepository<SingleValueProviderObject>,
                              address: String,
                              assetId: WalletAssetId,
                              chain: Chain) throws -> TotalRewardItem? {
        let operationManager = OperationManager()
        let logger = Logger.shared

        let trigger = DataProviderProxyTrigger()

        let source = SubscanRewardSource(address: address,
                                         assetId: assetId,
                                         chain: chain,
                                         targetIdentifier: address,
                                         repository: AnyDataProviderRepository(repository),
                                         operationFactory: SubscanOperationFactory(),
                                         trigger: trigger,
                                         operationManager: operationManager,
                                         logger: logger)

        let provider = SingleValueProvider(targetIdentifier: address,
                                           source: AnySingleValueProviderSource(source),
                                           repository: AnyDataProviderRepository(repository),
                                           updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var totalReward: TotalRewardItem? = nil

        let changesClosure = { (changes: [DataProviderChange<TotalRewardItem>]) -> Void in
            totalReward = changes.reduceToLastChange()
            expectation.fulfill()
        }

        let failureClosure = { (error: Error) -> Void in
            XCTFail("Unexpected error: \(error)")

            expectation.fulfill()
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true,
                                                  waitsInProgressSyncOnAdd: false)

        provider.addObserver(self,
                             deliverOn: .main,
                             executing: changesClosure,
                             failing: failureClosure,
                             options: options)

        wait(for: [expectation], timeout: 10.0)

        provider.removeObserver(self)

        return totalReward
    }
}
