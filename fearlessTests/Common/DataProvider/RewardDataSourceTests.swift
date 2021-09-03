import XCTest
@testable import fearless
import RobinHood

class RewardDataSourceTests: NetworkBaseTests {

    func testCorrectSyncAfterMultipleUpdates() {
        do {
            // given

            let storageFacade = SubstrateStorageTestFacade()
            let url = WalletAssetId.westend.subqueryHistoryUrl
            TotalRewardMock.register(mock: .westendFirst, url: url!)

            let expectedRewardAfterFirst: Decimal = 2.0
            let expectedRewardAfterSecond: Decimal = 5.0

            // when

            let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
                storageFacade.createRepository()

            let rewardAfterFirstCall = try performRewardRequest(for: AnyDataProviderRepository(repository),
                                                                address: WestendStub.address,
                                                                assetId: .westend,
                                                                chain: .westend).get()

            // then

            XCTAssertEqual(rewardAfterFirstCall?.amount.decimalValue, expectedRewardAfterFirst)

            TotalRewardMock.register(mock: .westendSecond, url: url!)

            let rewardAfterSecondCall = try performRewardRequest(for: AnyDataProviderRepository(repository),
                                                                 address: WestendStub.address,
                                                                 assetId: .westend,
                                                                 chain: .westend).get()

            XCTAssertEqual(rewardAfterSecondCall?.amount.decimalValue, expectedRewardAfterSecond)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFailureCorrectlyHandled() {
        do {
            // given

            let storageFacade = SubstrateStorageTestFacade()
            let url = WalletAssetId.westend.subqueryHistoryUrl
            TotalRewardMock.register(mock: .error, url: url!)

            // when

            let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
                storageFacade.createRepository()

            let result = try performRewardRequest(
                for: AnyDataProviderRepository(repository),
                address: WestendStub.address,
                assetId: .westend,
                chain: .westend
            )

            // then

            switch result {
            case .success:
                XCTFail("Error expected")
            case let .failure(error):
                XCTAssertTrue(error is SubqueryErrors, "Unexpected result error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func performRewardRequest(for repository: AnyDataProviderRepository<SingleValueProviderObject>,
                              address: String,
                              assetId: WalletAssetId,
                              chain: Chain) throws -> Result<TotalRewardItem?, Error> {
        let operationManager = OperationManager()

        let trigger = DataProviderProxyTrigger()

        let operationFactory = SubqueryHistoryOperationFactory(
            url: assetId.subqueryHistoryUrl!,
            filter: [.rewardsAndSlashes]
        )

        let source = SubqueryRewardSource(address: address,
                                         chain: chain,
                                         targetIdentifier: address,
                                         repository: AnyDataProviderRepository(repository),
                                         operationFactory: operationFactory,
                                         trigger: trigger,
                                         operationManager: operationManager)

        let provider = SingleValueProvider(targetIdentifier: address,
                                           source: AnySingleValueProviderSource(source),
                                           repository: AnyDataProviderRepository(repository),
                                           updateTrigger: trigger)

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2

        var totalReward: TotalRewardItem? = nil
        var totalRewardError: Error? = nil

        let changesClosure = { (changes: [DataProviderChange<TotalRewardItem>]) -> Void in
            totalReward = changes.reduceToLastChange()
            expectation.fulfill()
        }

        let failureClosure = { (error: Error) -> Void in
            totalRewardError = error
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

        if let error = totalRewardError {
            return .failure(error)
        } else {
            return .success(totalReward)
        }
    }
}
