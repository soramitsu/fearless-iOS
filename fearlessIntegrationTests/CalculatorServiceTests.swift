import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import SoraFoundation

class CalculatorServiceTests: XCTestCase {

    func testKusamaCalculatorSetupWithoutCache() throws {
        measure {
            do {
                let storageFacade = SubstrateStorageTestFacade()
                try performTest(for: .kusama, storageFacade: storageFacade)
            } catch {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testKusamaCalculatorSetupWithCache() throws {
        let storageFacade = SubstrateDataStorageFacade.shared
        measure {
            do {
                try performTest(for: .kusama, storageFacade: storageFacade)
            } catch {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    private func performTest(for chain: Chain, storageFacade: StorageFacadeProtocol) throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            networkType: chain,
                                                            keychain: keychain,
                                                            settings: settings)

        let operationManager = OperationManagerFacade.sharedManager

        let runtimeService = try createRuntimeService(from: storageFacade,
                                                      operationManager: operationManager,
                                                      chain: chain)

        runtimeService.setup()

        let webSocketService = createWebSocketService(storageFacade: storageFacade,
                                                      settings: settings)
        webSocketService.setup()

        let validatorService = createEraValidatorsService(storageFacade: storageFacade,
                                                          runtimeService: runtimeService,
                                                          operationManager: operationManager)

        if let engine = webSocketService.connection {
            validatorService.update(to: chain, engine: engine)
        }

        validatorService.setup()

        let calculatorService = createCalculationService(storageFacade: storageFacade,
                                                         eraValidatorService: validatorService,
                                                         runtimeService: runtimeService,
                                                         operationManager: operationManager)
        calculatorService.update(to: chain)
        calculatorService.setup()

        let operation = calculatorService.fetchCalculatorOperation()

        let expectation = XCTestExpectation()

        operation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    _ = try operation.extractNoCancellableResultData()
                } catch {
                    XCTFail("unexpected error \(error)")
                }

                expectation.fulfill()
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)

        wait(for: [expectation], timeout: 20.0)
    }

    private func createRuntimeService(from storageFacade: StorageFacadeProtocol,
                                      operationManager: OperationManagerProtocol,
                                      chain: Chain,
                                      logger: LoggerProtocol? = nil) throws
    -> RuntimeRegistryService {
        let providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                           operationManager: operationManager,
                                                           logger: logger)

        let topDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
        let runtimeDirectory = topDirectory.appendingPathComponent("runtime").path
        let filesRepository = RuntimeFilesOperationFacade(repository: FileRepository(),
                                                          directoryPath: runtimeDirectory)

        return RuntimeRegistryService(chain: chain,
                                      metadataProviderFactory: providerFactory,
                                      dataOperationFactory: DataOperationFactory(),
                                      filesOperationFacade: filesRepository,
                                      operationManager: operationManager,
                                      eventCenter: EventCenter.shared,
                                      logger: logger)
    }

    private func createWebSocketService(storageFacade: StorageFacadeProtocol,
                                        settings: SettingsManagerProtocol) -> WebSocketServiceProtocol {
        let connectionItem = settings.selectedConnection
        let address = settings.selectedAccount?.address

        let settings = WebSocketServiceSettings(url: connectionItem.url,
                                                addressType: connectionItem.type,
                                                address: address)
        let factory = WebSocketSubscriptionFactory(storageFacade: storageFacade)
        return WebSocketService(settings: settings,
                                connectionFactory: WebSocketEngineFactory(),
                                subscriptionsFactory: factory,
                                applicationHandler: ApplicationHandler())
    }

    private func createEraValidatorsService(storageFacade: StorageFacadeProtocol,
                                            runtimeService: RuntimeCodingServiceProtocol,
                                            operationManager: OperationManagerProtocol,
                                            logger: LoggerProtocol? = nil)
    -> EraValidatorService {
        let factory = SubstrateDataProviderFactory(facade: storageFacade, operationManager: operationManager)
        return EraValidatorService(storageFacade: storageFacade,
                                   runtimeCodingService: runtimeService,
                                   providerFactory: factory,
                                   operationManager: operationManager,
                                   logger: logger)
    }

    private func createCalculationService(storageFacade: StorageFacadeProtocol,
                                          eraValidatorService: EraValidatorServiceProtocol,
                                          runtimeService: RuntimeCodingServiceProtocol,
                                          operationManager: OperationManagerProtocol,
                                          logger: LoggerProtocol? = nil) -> RewardCalculatorService {
        let factory = SubstrateDataProviderFactory(facade: storageFacade, operationManager: operationManager)
        return RewardCalculatorService(eraValidatorsService: eraValidatorService,
                                       logger: logger,
                                       operationManager: operationManager,
                                       providerFactory: factory,
                                       runtimeCodingService: runtimeService,
                                       storageFacade: storageFacade)
    }
}
