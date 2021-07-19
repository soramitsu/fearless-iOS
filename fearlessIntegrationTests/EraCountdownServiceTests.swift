import XCTest
import RobinHood
import FearlessUtils
import SoraKeystore
@testable import fearless

class EraCountdownServiceTests: XCTestCase {

    func testService() {
        let operationManager = OperationManagerFacade.sharedManager

        WebSocketService.shared.setup()
        let connection = WebSocketService.shared.connection!
        let runtimeService = RuntimeRegistryFacade.sharedService
        runtimeService.setup()

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let service = EraCountdownService(
            chain: .westend,
            runtimeCodingService: runtimeService,
            storageRequestFactory: storageRequestFactory,
            engine: connection
        )

        let expectation = XCTestExpectation()
        let operation = service.fetchCountdownOperationWrapper()
        operation.targetOperation.completionBlock = {
            do {
                let res = try operation.targetOperation.extractNoCancellableResultData()
                print(res)
                expectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        operationManager.enqueue(operations: operation.allOperations, in: .transient)

        wait(for: [expectation], timeout: 20)
    }
}
