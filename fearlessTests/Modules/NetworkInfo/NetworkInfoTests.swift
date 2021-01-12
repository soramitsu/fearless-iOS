import XCTest
@testable import fearless
import SoraFoundation
import RobinHood
import Cuckoo
import SoraKeystore

class NetworkInfoTests: XCTestCase {
    func testCopyAddress() {
        // given

        let view = MockNetworkInfoViewProtocol()
        let wireframe = MockNetworkInfoWireframeProtocol()

        let connectionItem = ConnectionItem.defaultConnection
        let presenter = NetworkInfoPresenter(connectionItem: connectionItem,
                                             mode: [.none],
                                             localizationManager: LocalizationManager.shared)

        let mapper = ManagedConnectionItemMapper()
        let repository = UserDataStorageTestFacade()
            .createRepository(filter: nil,
                              sortDescriptors: [NSSortDescriptor.connectionsByOrder],
                              mapper: AnyCoreDataMapper(mapper))

        let settingsManager = InMemorySettingsManager()

        let eventCenter = MockEventCenterProtocol()

        let substrateOperationFactory = SubstrateOperationFactory(logger: Logger.shared)
        let interactor = NetworkInfoInteractor(repository: AnyDataProviderRepository(repository),
                                               substrateOperationFactory: substrateOperationFactory,
                                               settingsManager: settingsManager,
                                               operationManager: OperationManagerFacade.sharedManager,
                                               eventCenter: eventCenter)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        let nameExpectation = XCTestExpectation()
        let nodeExpectation = XCTestExpectation()
        let networkExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)
            when(stub).set(nameViewModel: any()).then { _ in
                nameExpectation.fulfill()
            }

            when(stub).set(nodeViewModel: any()).then { _ in
                nodeExpectation.fulfill()
            }

            when(stub).set(networkType: any()).then { _ in
                networkExpectation.fulfill()
            }
        }

        let copyExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.presentSuccessNotification(any(), from: any(), completion: any()).then { _ in
                copyExpectation.fulfill()
            }
        }

        // when

        presenter.setup()

        // then

        wait(for: [nameExpectation, nodeExpectation, networkExpectation],
             timeout: Constants.defaultExpectationDuration)

        // when

        presenter.activateCopy()

        // then

        wait(for: [copyExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testUpdateConnection() throws {
        // given

        let operationQueue = OperationQueue()

        let mapper = ManagedConnectionItemMapper()
        let repository = UserDataStorageTestFacade()
            .createRepository(filter: nil,
                              sortDescriptors: [NSSortDescriptor.connectionsByOrder],
                              mapper: AnyCoreDataMapper(mapper))

        let initManagedItem = ManagedConnectionItem(title: "My node",
                                                    url: URL(string: "wss://supernode.io")!,
                                                    type: .kusamaMain,
                                                    order: 1)

        let expectedItem = ManagedConnectionItem(title: "My next node",
                                                 url: URL(string: "wss://supernode2.io")!,
                                                 type: .kusamaMain,
                                                 order: 1)

        let saveOperation = repository.saveOperation({
            [initManagedItem]
        }, { [] })

        let view = MockNetworkInfoViewProtocol()
        let wireframe = MockNetworkInfoWireframeProtocol()

        let presenter = NetworkInfoPresenter(connectionItem: ConnectionItem(managedConnectionItem: initManagedItem),
                                             mode: .all,
                                             localizationManager: LocalizationManager.shared)

        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        let settingsManager = InMemorySettingsManager()

        let eventCenter = MockEventCenterProtocol()

        let substrateOperationFactory = MockSubstrateOperationFactoryProtocol()
        let interactor = NetworkInfoInteractor(repository: AnyDataProviderRepository(repository),
                                               substrateOperationFactory: substrateOperationFactory,
                                               settingsManager: settingsManager,
                                               operationManager: OperationManagerFacade.sharedManager,
                                               eventCenter: eventCenter)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        let nameExpectation = XCTestExpectation()
        let nodeExpectation = XCTestExpectation()
        let networkExpectation = XCTestExpectation()

        stub(substrateOperationFactory) { stub in
            stub.fetchChainOperation(any()).then { _ in
                let operation: BaseOperation<String> = BaseOperation()
                operation.result = .success(Chain.kusama.rawValue)
                return operation
            }
        }

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)
            when(stub).set(nameViewModel: any()).then { viewModel in
                viewModel.inputHandler.changeValue(to: expectedItem.title)
                nameExpectation.fulfill()
            }
            when(stub).set(nodeViewModel: any()).then { viewModel in
                viewModel.inputHandler.changeValue(to: expectedItem.url.absoluteString)
                nodeExpectation.fulfill()
            }
            when(stub).set(networkType: any()).then { _ in
                networkExpectation.fulfill()
            }
            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.close(view: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        // when

        presenter.setup()

        // then

        wait(for: [nameExpectation, nodeExpectation, networkExpectation],
             timeout: Constants.defaultExpectationDuration)

        // when

        presenter.activateUpdate()

        // then

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

        let fetchedItems = try fetchOperation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        XCTAssertEqual(fetchedItems, [expectedItem])
    }
}
