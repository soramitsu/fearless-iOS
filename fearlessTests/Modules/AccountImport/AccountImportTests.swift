import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import Cuckoo
import SoraFoundation

class AccountImportTests: XCTestCase {

    func testMnemonicRestore() {
        // given

        let view = MockAccountImportViewProtocol()
        let wireframe = MockAccountImportWireframeProtocol()

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let operationFactory = AccountOperationFactory(keystore: keychain)

        let keystoreImportService = KeystoreImportService(logger: Logger.shared)

        let accountRepository = AccountRepositoryFactory.createRepository(for: UserDataStorageTestFacade())

        let interactor = AccountImportInteractor(accountOperationFactory: operationFactory,
                                                 accountRepository: AnyDataProviderRepository(accountRepository),
                                                 operationManager: OperationManager(),
                                                 settings: settings,
                                                 keystoreImportService: keystoreImportService)

        let expectedUsername = "myname"
        let expetedMnemonic = "great fog follow obtain oyster raw patient extend use mirror fix balance blame sudden vessel"

        let presenter = AccountImportPresenter()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        let setupExpectation = XCTestExpectation()
        setupExpectation.expectedFulfillmentCount = 2

        var sourceInputViewModel: InputViewModelProtocol?
        var usernameViewModel: InputViewModelProtocol?

        stub(view) { stub in
            when(stub).didCompleteSourceTypeSelection().thenDoNothing()
            when(stub).didCompleteCryptoTypeSelection().thenDoNothing()
            when(stub).didCompleteAddressTypeSelection().thenDoNothing()
            when(stub).didValidateDerivationPath(any()).thenDoNothing()
            when(stub).isSetup.get.thenReturn(false, true)

            when(stub).setSource(viewModel: any()).then { viewModel in
                sourceInputViewModel = viewModel

                setupExpectation.fulfill()
            }

            when(stub).setName(viewModel: any()).then { viewModel in
                usernameViewModel = viewModel

                setupExpectation.fulfill()
            }

            when(stub).setSource(type: any()).thenDoNothing()
            when(stub).setSelectedCrypto(model: any()).thenDoNothing()
            when(stub).setSelectedNetwork(model: any()).thenDoNothing()
            when(stub).setDerivationPath(viewModel: any()).thenDoNothing()
        }

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).proceed(from: any()).then { _ in
                expectation.fulfill()
            }
        }

        // when

        presenter.setup()

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        _ = sourceInputViewModel?.inputHandler.didReceiveReplacement(expetedMnemonic,
                                                                     for: NSRange(location: 0, length: 0));

        _ = usernameViewModel?.inputHandler.didReceiveReplacement(expectedUsername,
                                                                  for: NSRange(location: 0, length: 0))

        presenter.proceed()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)

        guard let selectedAccount = settings.selectedAccount else {
            XCTFail("Unexpected empty account")
            return
        }

        XCTAssertEqual(selectedAccount.username, expectedUsername)

        XCTAssertTrue(try keychain.checkSecretKeyForAddress(selectedAccount.address))
        XCTAssertTrue(try keychain.checkEntropyForAddress(selectedAccount.address))
        XCTAssertFalse(try keychain.checkDeriviationForAddress(selectedAccount.address))
    }
}
