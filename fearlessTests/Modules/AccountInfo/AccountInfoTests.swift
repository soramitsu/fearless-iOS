import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import Cuckoo
import SoraFoundation

class AccountInfoTests: XCTestCase {

    func testSaveUsername() throws {
        // given

        let facade = UserDataStorageTestFacade()

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        try AccountCreationHelper.createAccountFromSeed(Data(repeating: 0, count: 32).toHex(),
                                                        cryptoType: .sr25519,
                                                        keychain: keychain,
                                                        settings: settings)

        let givenAccount = settings.selectedAccount!

        let accountsRepository = AccountRepositoryFactory.createRepository(for: facade)
        let operation = accountsRepository.saveOperation({ [givenAccount]}, { [] })

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let mapper = ManagedAccountItemMapper()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let view = MockAccountInfoViewProtocol()
        let wireframe = MockAccountInfoWireframeProtocol()

        let usernameExpectation = XCTestExpectation()
        let addressExpectation = XCTestExpectation()
        let networkExpectation = XCTestExpectation()
        let cryptoExpectation = XCTestExpectation()

        var usernameViewModel: InputViewModelProtocol?

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)
            when(stub).set(usernameViewModel: any(InputViewModelProtocol.self)).then { viewModel in
                usernameViewModel = viewModel
                usernameExpectation.fulfill()
            }

            when(stub).set(address: any()).then { _ in
                addressExpectation.fulfill()
            }

            when(stub).set(networkType: any()).then { _ in
                networkExpectation.fulfill()
            }

            when(stub).set(cryptoType: any()).then { _ in
                cryptoExpectation.fulfill()
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

        stub(wireframe) { stub in
            when(stub).close(view: any()).thenDoNothing()
        }

        let presenter = AccountInfoPresenter(address: givenAccount.address,
                                             localizationManager: LocalizationManager.shared)
        let interactor = AccountInfoInteractor(repository: AnyDataProviderRepository(repository),
                                               settings: settings,
                                               keystore: keychain,
                                               eventCenter: eventCenter,
                                               operationManager: OperationManager(),
                                               saveUsernameInterval: Constants.defaultExpectationDuration / 4.0)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        presenter.setup()

        // then

        wait(for: [usernameExpectation, cryptoExpectation, addressExpectation, networkExpectation],
             timeout: Constants.defaultExpectationDuration)

        // when

        let newUsername = "newName"

        usernameViewModel?.inputHandler.changeValue(to: newUsername)

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(settings.selectedAccount?.username, newUsername)

        let fetchOperation = repository.fetchOperation(by: givenAccount.identifier,
                                                       options: RepositoryFetchOptions())
        OperationQueue().addOperations([fetchOperation], waitUntilFinished: true)

        let newAccount = try fetchOperation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        XCTAssertEqual(newAccount?.username, newUsername)
    }
}
