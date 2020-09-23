import XCTest
@testable import fearless
import RobinHood
import SoraFoundation
import Cuckoo

class ModifyConnectionTests: XCTestCase {

    func testConnectionAdd() throws {
        // given

        let view = MockModifyConnectionViewProtocol()
        let wireframe = MockModifyConnectionWireframeProtocol()

        let substrateFactory = MockSubstrateOperationFactoryProtocol()

        let facade = UserDataStorageTestFacade()

        let mapper = ManagedConnectionItemMapper()
        let repository: CoreDataRepository<ManagedConnectionItem, CDConnectionItem> = facade
            .createRepository(filter: nil,
                              sortDescriptors: [NSSortDescriptor.connectionsByOrder],
                              mapper: AnyCoreDataMapper(mapper))

        let interactor = ModifyConnectionInteractor(repository: AnyDataProviderRepository(repository),
                                                    operationManager: OperationManagerFacade.sharedManager,
                                                    substrateOperationFactory: substrateFactory)

        let presenter = ModifyConnectionPresenter(localizationManager: LocalizationManager.shared)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        let expectedConnectionItem = ManagedConnectionItem(title: "My node",
                                                           url: URL(string: "wss://somenode.com")!,
                                                           type: .kusamaMain,
                                                           order: 1)

        let nameExpectation = XCTestExpectation()
        let nodeExpectation = XCTestExpectation()

        stub(view) { stub in
            stub.isSetup.get.thenReturn(false, true)
            stub.didStartLoading().thenDoNothing()
            stub.didStopLoading().thenDoNothing()

            stub.set(nameViewModel: any()).then { viewModel in
                _ = viewModel.inputHandler.didReceiveReplacement(expectedConnectionItem.title,
                                                                 for: NSRange(location: 0, length: 0))

                nameExpectation.fulfill()
            }

            stub.set(nodeViewModel: any()).then { viewModel in
                _ = viewModel.inputHandler.didReceiveReplacement(expectedConnectionItem.url.absoluteString,
                                                                 for: NSRange(location: 0, length: 0))

                nodeExpectation.fulfill()
            }
        }

        stub(substrateFactory) { stub in
            stub.fetchChainOperation(any()).then { _ in
                let operation: BaseOperation<String> = BaseOperation()
                operation.result = .success(Chain.kusama.rawValue)
                return operation
            }
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

        wait(for: [nameExpectation, nodeExpectation], timeout: Constants.defaultExpectationDuration)

        // when

        presenter.add()

        // then

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([fetchOperation], waitUntilFinished: true)

        let savedItems = try fetchOperation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        XCTAssertEqual([expectedConnectionItem], savedItems)
    }
}
