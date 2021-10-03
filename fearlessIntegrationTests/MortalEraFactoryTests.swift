import XCTest
@testable import fearless
import IrohaCrypto

class MortalEraFactoryTests: XCTestCase {
    func testMortalEraPolkadot() {
        performMortalEraCalculation(chainId: Chain.polkadot.genesisHash)
    }

    func testMortalEraKusama() {
        performMortalEraCalculation(chainId: Chain.kusama.genesisHash)
    }

    func testMortalEraWestend() {
        performMortalEraCalculation(chainId: Chain.westend.genesisHash)
    }


    func performMortalEraCalculation(chainId: ChainModel.Id) {
        // given
        let logger = Logger.shared

        do {
            let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(
                with: SubstrateStorageTestFacade()
            )

            let connection = chainRegistry.getConnection(for: chainId)!
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!

            let operationFactory = MortalEraOperationFactory()
            let wrapper = operationFactory.createOperation(from: connection, runtimeService: runtimeService)

            let operationQueue = OperationQueue()
            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

            let era = try wrapper.targetOperation.extractNoCancellableResultData()

            logger.info("Did receive era: \(era)")

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
