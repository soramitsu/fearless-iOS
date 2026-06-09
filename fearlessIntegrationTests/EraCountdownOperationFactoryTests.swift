import XCTest
import RobinHood
import SSFUtils
import SSFModels
@testable import fearless

class EraCountdownOperationFactoryTests: XCTestCase {

    func testService() throws {
        guard Self.remoteEndpointTestsEnabled else {
            throw XCTSkip("Era countdown integration depends on remote chain endpoints; set FEARLESS_RUN_REMOTE_INTEGRATION_TESTS=1 to run it")
        }

        let operationManager: OperationManagerProtocol = OperationManager()

        let chainId = Chain.kusama.genesisHash
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: SubstrateStorageTestFacade())

        guard !chainRegistry.availableChains.isEmpty else {
            throw XCTSkip("Chain registry integration setup is unavailable in the current environment")
        }

        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)
        else {
            throw XCTSkip("Kusama integration services are unavailable in the current environment")
        }

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let factory = EraCountdownOperationFactory(storageRequestFactory: storageRequestFactory)

        let timeExpectation = XCTestExpectation()
        let operationWrapper = factory.fetchCountdownOperationWrapper(
            for: connection,
            runtimeService: runtimeService
        )
        operationWrapper.targetOperation.completionBlock = {
            do {
                let eraCountdown = try operationWrapper.targetOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                Logger.shared.info(
                    "Estimating era completion time (in seconds): \(eraCountdown.timeIntervalTillNextActiveEraStart())"
                )
                timeExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)

        wait(for: [timeExpectation], timeout: 20)
    }

    private static var remoteEndpointTestsEnabled: Bool {
        ProcessInfo.processInfo.environment["FEARLESS_RUN_REMOTE_INTEGRATION_TESTS"] == "1"
    }
}
