import XCTest
import RobinHood
import FearlessUtils
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

        let timeExpectation = XCTestExpectation()
        let operationWrapper = service.fetchCountdownOperationWrapper()
        operationWrapper.targetOperation.completionBlock = {
            do {
                let eraCompletionTime = try operationWrapper.targetOperation.extractNoCancellableResultData()
                print("Estimating era completion time (in seconds): \(eraCompletionTime / 1000)")
                timeExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)

        wait(for: [timeExpectation], timeout: 20)
    }
}
