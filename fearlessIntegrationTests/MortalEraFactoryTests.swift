import XCTest
@testable import fearless
import IrohaCrypto
import SSFModels
import RobinHood

class MortalEraFactoryTests: XCTestCase {
    func testMortalEraPolkadot() throws {
        try performMortalEraCalculation(chainId: Chain.polkadot.genesisHash)
    }

    func testMortalEraKusama() throws {
        try performMortalEraCalculation(chainId: Chain.kusama.genesisHash)
    }

    func testMortalEraWestend() throws {
        try performMortalEraCalculation(chainId: Chain.westend.genesisHash)
    }


    func performMortalEraCalculation(chainId: ChainModel.Id) throws {
        guard Self.remoteEndpointTestsEnabled else {
            throw XCTSkip("Mortal era integration depends on remote chain endpoints; set FEARLESS_RUN_REMOTE_INTEGRATION_TESTS=1 to run it")
        }

        // given
        let logger = Logger.shared

        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(
            with: SubstrateStorageTestFacade()
        )

        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)
        else {
            throw XCTSkip("Mortal era integration setup is unavailable in the current environment")
        }

        let operationFactory = MortalEraOperationFactory()
        let wrapper = operationFactory.createOperation(from: connection, runtimeService: runtimeService)

        let operationQueue = OperationQueue()
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        let era = try wrapper.targetOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        logger.info("Did receive era: \(era)")
    }

    private static var remoteEndpointTestsEnabled: Bool {
        ProcessInfo.processInfo.environment["FEARLESS_RUN_REMOTE_INTEGRATION_TESTS"] == "1"
    }
}
