import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import Cuckoo
import SoraFoundation

class AccountInfoExportTests: XCTestCase {

    func testExportAfterCreationWithMnemonic() throws {
        let facade = UserDataStorageTestFacade()

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            keychain: keychain,
                                                            settings: settings)

        let givenAccount = settings.selectedAccount!

        let accountsRepository: CoreDataRepository<AccountItem, CDAccountItem> = facade.createRepository()
        let operation = accountsRepository.saveOperation({ [givenAccount]}, { [] })

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        performTestWithFacade(facade,
                              keystore: keychain,
                              settings: settings,
                              expectedAddress: givenAccount.address,
                              expectedOptions: [.keystore, .mnemonic, .seed])
    }

    func testExportAfterCreationWithSeed() throws {
        let facade = UserDataStorageTestFacade()

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        try AccountCreationHelper.createAccountFromSeed(Data(repeating: 1, count: 32).toHex(),
                                                        cryptoType: .sr25519,
                                                        keychain: keychain,
                                                        settings: settings)

        let givenAccount = settings.selectedAccount!

        let accountsRepository: CoreDataRepository<AccountItem, CDAccountItem> = facade.createRepository()
        let operation = accountsRepository.saveOperation({ [givenAccount]}, { [] })

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        performTestWithFacade(facade,
                              keystore: keychain,
                              settings: settings,
                              expectedAddress: givenAccount.address,
                              expectedOptions: [.keystore, .seed])
    }

    func testExportAfterCreationWithKeystore() throws {
        let facade = UserDataStorageTestFacade()

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        try AccountCreationHelper.createAccountFromKeystore(Constants.validSrKeystoreName,
                                                            password: Constants.validSrKeystorePassword,
                                                            keychain: keychain,
                                                            settings: settings)

        let givenAccount = settings.selectedAccount!

        let accountsRepository: CoreDataRepository<AccountItem, CDAccountItem> = facade.createRepository()
        let operation = accountsRepository.saveOperation({ [givenAccount]}, { [] })

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        performTestWithFacade(facade,
                              keystore: keychain,
                              settings: settings,
                              expectedAddress: givenAccount.address,
                              expectedOptions: [.keystore])
    }

    private func performTestWithFacade(_ facade: UserDataStorageTestFacade,
                                       keystore: KeystoreProtocol,
                                       settings: SettingsManagerProtocol,
                                       expectedAddress: String,
                                       expectedOptions: [ExportOption]) {
        // given

        let mapper = ManagedAccountItemMapper()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let view = MockAccountInfoViewProtocol()
        let wireframe = MockAccountInfoWireframeProtocol()

        let usernameExpectation = XCTestExpectation()
        let addressExpectation = XCTestExpectation()
        let networkExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)
            when(stub).set(usernameViewModel: any(InputViewModelProtocol.self)).then { _ in
                usernameExpectation.fulfill()
            }

            when(stub).set(address: any()).then { _ in
                addressExpectation.fulfill()
            }

            when(stub).set(networkType: any()).then { _ in
                networkExpectation.fulfill()
            }
        }

        let presenter = AccountInfoPresenter(address: expectedAddress,
                                             localizationManager: LocalizationManager.shared)
        let interactor = AccountInfoInteractor(repository: AnyDataProviderRepository(repository),
                                               settings: settings,
                                               keystore: keystore,
                                               eventCenter: MockEventCenterProtocol(),
                                               operationManager: OperationManager())

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        presenter.setup()

        wait(for: [usernameExpectation, addressExpectation, networkExpectation],
             timeout: Constants.defaultExpectationDuration)

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub)
                .showExport(for: any(), options: any(), locale: any(), from: any()).then { (accountId, options, _, _) in
                XCTAssertEqual(accountId, expectedAddress)
                XCTAssertEqual(options, expectedOptions)
                completionExpectation.fulfill()
            }
        }

        presenter.activateExport()

        // then

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
