import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import SoraFoundation
import FearlessUtils

class RewardPayoutsServiceTests: XCTestCase {

    func testSubscriptionToHistoryDepth() {
        measure {
            do {
                let chain = Chain.westend
                let storageFacade = SubstrateDataStorageFacade.shared

                let settings = InMemorySettingsManager()
                let keychain = InMemoryKeychain()

                try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                                    networkType: chain,
                                                                    keychain: keychain,
                                                                    settings: settings)

                let webSocketService = createWebSocketService(
                    storageFacade: storageFacade,
                    settings: settings)

                webSocketService.setup()

                let syncQueue = DispatchQueue(label: "test.\(UUID().uuidString)")

                let localFactory = try ChainStorageIdFactory(chain: chain)

                let path = StorageCodingPath.historyDepth
                let key = try StorageKeyFactory().createStorageKey(
                    moduleName: path.moduleName,
                    storageName: path.itemName)

                let localKey = localFactory.createIdentifier(for: key)
                let historyDepthDataProvider = SubstrateDataProviderFactory(
                    facade: storageFacade,
                    operationManager: OperationManager()
                )
                .createStorageProvider(for: localKey)

                let expectation = XCTestExpectation(description: "Obtained history depth")

                let updateClosure: ([DataProviderChange<ChainStorageItem>]) -> Void = { changes in
                    let finalValue: ChainStorageItem? = changes.reduce(nil) { (_, item) in
                        switch item {
                        case .insert(let newItem), .update(let newItem):
                            return newItem
                        case .delete:
                            return nil
                        }
                    }

                    if let value = finalValue {
                        do {
                            let decoder = try ScaleDecoder(data: value.data)
                            let historyDepthValue = try UInt32(scaleDecoder: decoder)
                            XCTAssertEqual(historyDepthValue, 84)
                        } catch {
                            XCTFail("History depth decoding error: \(error)")
                        }

                        expectation.fulfill()
                    }
                }

                let failureClosure: (Error) -> Void = { (error) in
                    XCTFail("Unexpected error: \(error)")
                    expectation.fulfill()
                }

                historyDepthDataProvider.addObserver(
                    self,
                    deliverOn: syncQueue,
                    executing: updateClosure,
                    failing: failureClosure,
                    options: StreamableProviderObserverOptions.substrateSource())

                wait(for: [expectation], timeout: 10.0)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    private func createWebSocketService(storageFacade: StorageFacadeProtocol,
                                        settings: SettingsManagerProtocol) -> WebSocketServiceProtocol {
        let connectionItem = settings.selectedConnection
        let address = settings.selectedAccount?.address

        let settings = WebSocketServiceSettings(
            url: connectionItem.url,
            addressType: connectionItem.type,
            address: address)

        let factory = WebSocketSubscriptionFactory(storageFacade: storageFacade)
        return WebSocketService(
            settings: settings,
            connectionFactory: WebSocketEngineFactory(),
            subscriptionsFactory: factory,
            applicationHandler: ApplicationHandler())
    }

}
