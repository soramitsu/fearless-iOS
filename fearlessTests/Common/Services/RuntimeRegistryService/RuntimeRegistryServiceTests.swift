import XCTest
@testable import fearless
import RobinHood
import Cuckoo

class RuntimeRegistryServiceTests: NetworkBaseTests {
    func testTypeRegistryCreationEventDelivered() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let eventCenter = MockEventCenterProtocol()
        let operationManager = OperationManager()

        let service = createDefaultService(storageFacade: storageFacade,
                                           eventCenter: eventCenter,
                                           operationManager: operationManager)

        // when

        let expectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is TypeRegistryPrepared {
                    expectation.fulfill()
                }
            }
        }

        service.setup()

        let repository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> = storageFacade.createRepository()
        try RuntimeMetadataCreationHelper.persistTestRuntimeMetadata(for: service.chain.genesisHash,
                                                                 version: 48,
                                                                 using: AnyDataProviderRepository(repository),
                                                                 operationManager: operationManager)

        // then

        wait(for: [expectation], timeout: 10.0)
    }

    func testCodingFactoryDelivered() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let eventCenter = MockEventCenterProtocol()
        let operationManager = OperationManager()

        let service = createDefaultService(storageFacade: storageFacade,
                                           eventCenter: eventCenter,
                                           operationManager: operationManager)

        // when

        stub(eventCenter) { stub in
            when(stub).notify(with: any()).thenDoNothing()
        }

        service.setup()

        let expectation = XCTestExpectation()

        let fetchFactoryOperation = service.fetchCoderFactoryOperation(with: 10.0)
        fetchFactoryOperation.completionBlock = {
            do {
                _ = try fetchFactoryOperation.extractNoCancellableResultData()
            } catch {
                XCTFail("Unexpected error: \(error)")
            }

            expectation.fulfill()
        }

        // then

        operationManager.enqueue(operations: [fetchFactoryOperation], in: .transient)

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            let repository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> = storageFacade.createRepository()
            try? RuntimeMetadataCreationHelper.persistTestRuntimeMetadata(for: service.chain.genesisHash,
                                                                          version: 48,
                                                                          using:    AnyDataProviderRepository(repository),
                                                                          operationManager: operationManager)
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: Private

    func createDefaultService(storageFacade: StorageFacadeProtocol,
                              eventCenter: EventCenterProtocol,
                              operationManager: OperationManagerProtocol) -> RuntimeRegistryService {
        let chain = Chain.westend
        TypeDefFileMock.register(mock: .westendDefault, url: chain.typeDefDefaultFileURL()!)
        TypeDefFileMock.register(mock: .westendNetwork, url: chain.typeDefNetworkFileURL()!)

        let logger = Logger.shared
        let providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                           operationManager: operationManager,
                                                           logger: logger)

        let directoryPath = FileManager.default.temporaryDirectory.appendingPathComponent("runtime").path
        let filesFacade = RuntimeFilesOperationFacade(repository: FileRepository(),
                                                      directoryPath: directoryPath)

        let service = RuntimeRegistryService(chain: .westend,
                                             metadataProviderFactory: providerFactory,
                                             dataOperationFactory: DataOperationFactory(),
                                             filesOperationFacade: filesFacade,
                                             operationManager: operationManager,
                                             eventCenter: eventCenter,
                                             logger: Logger.shared)

        return service
    }
}
