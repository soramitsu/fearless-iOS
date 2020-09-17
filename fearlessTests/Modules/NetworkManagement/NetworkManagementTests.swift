import XCTest
@testable import fearless
import SoraKeystore
import SoraFoundation
import IrohaCrypto
import RobinHood
import Cuckoo

class NetworkManagementTests: XCTestCase {

    func testInitialSetup() {
        // given

        let facade = UserDataStorageTestFacade()

        var settings = InMemorySettingsManager()

        settings.selectedConnection = ConnectionItem.supportedConnections.first!

        let managedConnections = ConnectionItem.supportedConnections.enumerated().map { (index, item) in
            return ManagedConnectionItem(title: item.title,
                                         url: URL(string: item.identifier)!,
                                         type: SNAddressType(rawValue: item.type)!,
                                         order: Int16(index))
        }

        let mapper = ManagedConnectionItemMapper()
        let connectionsRepository: CoreDataRepository<ManagedConnectionItem, CDConnectionItem> = facade.createRepository(mapper: AnyCoreDataMapper(mapper))
        let operation = connectionsRepository.saveOperation({ managedConnections }, { [] })

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let observer: CoreDataContextObservable<ManagedConnectionItem, CDConnectionItem> =
            CoreDataContextObservable(service: facade.databaseService,
                                                 mapper: AnyCoreDataMapper(mapper),
                                                 predicate: { _ in true })
        let repository = facade.createRepository(filter: nil,
                                                 sortDescriptors: [NSSortDescriptor.connectionsByOrder],
                                                 mapper: AnyCoreDataMapper(mapper))

        let view = MockNetworkManagementViewProtocol()
        let wireframe = MockNetworkManagementWireframeProtocol()

        let reloadExpectation = XCTestExpectation()

        // selected connection + default connections + custom connections
        reloadExpectation.expectedFulfillmentCount = 3

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)
            when(stub).reload().then {
                reloadExpectation.fulfill()
            }
        }

        let eventCenter = MockEventCenterProtocol()

        let completionExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
            when(stub).notify(with: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        let viewModelFactory = ManagedConnectionViewModelFactory()
        let presenter = NetworkManagementPresenter(localizationManager: LocalizationManager.shared,
                                                   viewModelFactory: viewModelFactory)
        let interactor = NetworkManagementInteractor(repository: AnyDataProviderRepository(repository),
                                                     repositoryObservable: AnyDataProviderRepositoryObservable(observer),
                                                     settings: settings,
                                                     operationManager: OperationManager(),
                                                     eventCenter: eventCenter)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        presenter.setup()

        // then

        wait(for: [reloadExpectation], timeout: Constants.defaultExpectationDuration)

    }
}
