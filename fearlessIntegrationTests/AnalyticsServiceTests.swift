import XCTest
import RobinHood
import SoraKeystore
@testable import fearless

class AnalyticsServiceTests: XCTestCase {

    func testRewards() {
        let address = "FFnTujhiUdTbhvwcBwQ2V3UtFMdpzg4r8SYT6J7qxhwW1s3"
        let networkType = Chain.kusama.addressType
        let settings = SettingsManager.shared
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)
        guard
            let assetId = WalletAssetId(rawValue: asset.identifier),
            let subqueryUrl = assetId.subqueryUrl
        else { return }

        let operationManager = OperationManagerFacade.sharedManager
        let service = AnalyticsService(
            url: subqueryUrl,
            address: address,
            operationManager: operationManager
        )

        let operation = service.longrunOperation()
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

        wait(for: [exp], timeout: 5)
    }
}
