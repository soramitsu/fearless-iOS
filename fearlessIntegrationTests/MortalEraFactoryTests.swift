import XCTest
@testable import fearless
import IrohaCrypto

class MortalEraFactoryTests: XCTestCase {
    func testMortalEraPolkadot() {
        let connectionItem = ConnectionItem(
            title: "Polkadot",
            url: URL(string: "wss://rpc.polkadot.io/")!,
            type: .polkadotMain
        )

        return performMortalEraCalculation(connectionItem)
    }

    func testMortalEraKusama() {
        let connectionItem = ConnectionItem(
            title: "Kusama",
            url: URL(string: "wss://kusama-rpc.polkadot.io")!,
            type: .kusamaMain
        )

        return performMortalEraCalculation(connectionItem)
    }

    func testMortalEraWestend() {
        let connectionItem = ConnectionItem(
            title: "Westend",
            url: URL(string: "wss://westend-rpc.polkadot.io/")!,
            type: .genericSubstrate
        )

        return performMortalEraCalculation(connectionItem)
    }


    func performMortalEraCalculation(_ connection: ConnectionItem) {
        // given
        let logger = Logger.shared

        do {
            let dummyAddress = try SS58AddressFactory().address(
                fromAccountId: Data(repeating: 0, count: 32),
                type: UInt16(connection.type.rawValue)
            )

            let settings = WebSocketServiceSettings(url: connection.url,
                                                    addressType: connection.type,
                                                    address: dummyAddress
            )

            let webSocketService = WebSocketServiceFactory.createService()
            let runtimeService = RuntimeRegistryFacade.sharedService

            // when
            webSocketService.update(settings: settings)

            let chain = connection.type.chain
            runtimeService.update(to: chain)

            webSocketService.setup()
            runtimeService.setup()

            guard let connection = webSocketService.connection else {
                XCTFail("Unexpected empty connection")
                return
            }

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
