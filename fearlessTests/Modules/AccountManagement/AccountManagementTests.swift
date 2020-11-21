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

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let seed1 = Data(repeating: 0, count: 32)
        let seed2 = Data(repeating: 1, count: 32)

        try AccountCreationHelper.createAccountFromSeed(seed1.toHex(),
                                                        cryptoType: .sr25519,
                                                        keychain: keychain,
                                                        settings: settings)

        let account1 = settings.selectedAccount!

        try AccountCreationHelper.createAccountFromSeed(seed2.toHex(),
                                                        cryptoType: .sr25519,
                                                        keychain: keychain,
                                                        settings: settings)

        let account2 = settings.selectedAccount!

        let accountsRepository: CoreDataRepository<AccountItem, CDAccountItem> = facade.createRepository()
        let operation = accountsRepository.saveOperation({ [account1, account2]}, { [] })

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let mapper = ManagedAccountItemMapper()
        let observer: CoreDataContextObservable<ManagedAccountItem, CDAccountItem> =
            CoreDataContextObservable(service: facade.databaseService,
                                                 mapper: AnyCoreDataMapper(mapper),
                                                 predicate: { _ in true })
        let repository = facade.createRepository(filter: nil,
                                                 sortDescriptors: [NSSortDescriptor.accountsByOrder],
                                                 mapper: AnyCoreDataMapper(mapper))

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
        let presenter = AccountManagementPresenter(viewModelFactory: viewModelFactory,
                                                   supportedNetworks: SNAddressType.supported)
        let interactor = AccountManagementInteractor(repository: AnyDataProviderRepository(repository),
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

        // when

        presenter.selectItem(at: 0, in: 0)

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(settings.selectedAccount, account1)

        verify(eventCenter, times(1)).notify(with: any())
    }
}
