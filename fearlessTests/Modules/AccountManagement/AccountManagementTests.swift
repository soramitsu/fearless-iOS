import XCTest
@testable import fearless
import SoraKeystore
import FearlessUtils
import IrohaCrypto
import RobinHood
import Cuckoo

class AccountManagementTests: XCTestCase {

    func testAccountSuccessfullySelected() throws {
        // given

        let facade = UserDataStorageTestFacade()

        let accountsCount = 10
        let accounts: [ManagedMetaAccountModel] = (0..<accountsCount).map { index in
            let info = AccountGenerator.generateMetaAccount()

            return ManagedMetaAccountModel(
                info: info,
                isSelected: index == accountsCount - 1,
                order: UInt32(index)
            )
        }

        let accountMapper = ManagedMetaAccountMapper()
        let accountsRepository = facade.createRepository(
            filter: nil,
            sortDescriptors: [NSSortDescriptor.accountsByOrder],
            mapper: AnyCoreDataMapper(accountMapper)
        )

        let operation = accountsRepository.saveOperation({ accounts }, { [] })

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let settings = SelectedWalletSettings(storageFacade: facade, operationQueue: OperationQueue())
        settings.setup()

        let observer: CoreDataContextObservable<ManagedMetaAccountModel, CDMetaAccount> =
            CoreDataContextObservable(service: facade.databaseService,
                                                 mapper: AnyCoreDataMapper(accountMapper),
                                                 predicate: { _ in true })

        let view = MockAccountManagementViewProtocol()
        let wireframe = MockAccountManagementWireframeProtocol()

        let reloadExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)
            when(stub).reload().then {
                reloadExpectation.fulfill()
            }
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).complete(from: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        let eventCenter = MockEventCenterProtocol()

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
            when(stub).notify(with: any()).thenDoNothing()
        }

        let viewModelFactory = ManagedAccountViewModelFactory(iconGenerator: PolkadotIconGenerator())
        let presenter = AccountManagementPresenter(viewModelFactory: viewModelFactory)
        let interactor = AccountManagementInteractor(
            repository: AnyDataProviderRepository(accountsRepository),
            repositoryObservable: AnyDataProviderRepositoryObservable(observer),
            settings: settings,
            operationQueue: OperationQueue(),
            eventCenter: eventCenter
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        presenter.setup()

        // then

        wait(for: [reloadExpectation], timeout: Constants.defaultExpectationDuration)

        // when

        presenter.selectItem(at: 0)

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(settings.value, accounts[0].info)

        verify(eventCenter, times(1)).notify(with: any())
    }
}
