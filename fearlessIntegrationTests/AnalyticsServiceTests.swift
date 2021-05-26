import XCTest
import RobinHood
@testable import fearless

class AnalyticsServiceTests: XCTestCase {

    func testRewards() {
        let address = "5CDayXd3cDCWpBkSXVsVfhE5bWKyTZdD3D1XUinR1ezS1sGn"
        let url = WalletAssetId.westend.subscanUrl!
            .appendingPathComponent(SubscanApi.rewardsAndSlashes)
        let subscanOperationFactory = SubscanOperationFactory()
        let operationManager = OperationManagerFacade.sharedManager
        let service = AnalyticsService(
            url: url,
            address: address,
            subscanOperationFactory: subscanOperationFactory,
            operationManager: operationManager
        )

        let operation = service.longrunOperation()

        operationManager.enqueue(operations: [operation], in: .transient)

        let exp = XCTestExpectation()

        operation.longrun.start { result in
            switch result {
            case let .success(data):
                if !data.isEmpty {
                    exp.fulfill()
                }
            case let .failure(error):
                XCTFail(error.localizedDescription)
            }
        }

        wait(for: [exp], timeout: 20)
    }
}
