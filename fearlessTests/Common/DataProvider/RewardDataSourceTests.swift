import XCTest
@testable import fearless
import RobinHood

class RewardDataSourceTests: NetworkBaseTests {

    func testCorrectSync() {
        do {
            // given

            let storageFacade = SubstrateStorageTestFacade()
            let chain = ChainModelGenerator.generateChain(
                generatingAssets: 1,
                addressPrefix: 42,
                assetPresicion: 12,
                hasStaking: true,
                hasCrowdloans: true
            )

            guard
                let url = chain.externalApi?.staking?.url,
                let assetPrecision = chain.assets.first?.displayInfo.assetPrecision else {
                XCTFail("Unexpected chain")
                return
            }

            TotalRewardMock.register(mock: .westend, url: url)

            let expectedReward: Decimal = 5.0

            // when

            let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
                storageFacade.createRepository()

            let actualRewardItem = try performRewardRequest(
                for: AnyDataProviderRepository(repository),
                address: WestendStub.address,
                url: url,
                assetPrecision: assetPrecision
            ).get()

            // then

            XCTAssertEqual(expectedReward, actualRewardItem?.amount.decimalValue)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFailureCorrectlyHandled() {
        do {
            // given

            let storageFacade = SubstrateStorageTestFacade()

            let chain = ChainModelGenerator.generateChain(
                generatingAssets: 1,
                addressPrefix: 42,
                assetPresicion: 12,
                hasStaking: true,
                hasCrowdloans: true
            )

            guard
                let url = chain.externalApi?.staking?.url,
                let assetPrecision = chain.assets.first?.displayInfo.assetPrecision else {
                XCTFail("Unexpected chain")
                return
            }

            TotalRewardMock.register(mock: .error, url: url)

            // when

            let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
                storageFacade.createRepository()

            let result = try performRewardRequest(
                for: AnyDataProviderRepository(repository),
                address: WestendStub.address,
                url: url,
                assetPrecision: assetPrecision
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
                              url: URL,
                              assetPrecision: Int16
    ) throws -> Result<TotalRewardItem?, Error> {
        let operationManager = OperationManager()

        let trigger = DataProviderProxyTrigger()

        let operationFactory = SubqueryRewardOperationFactory(
            url: url
        )

        let source = SubqueryRewardSource(address: address,
                                          assetPrecision: assetPrecision,
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
