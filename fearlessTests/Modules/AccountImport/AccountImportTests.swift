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

        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        let repository = AccountRepositoryFactory(
            storageFacade: UserDataStorageTestFacade())
            .createMetaAccountRepository(for: nil, sortDescriptors: [])

        let eventCenter = MockEventCenterProtocol()

        let keychain = InMemoryKeychain()
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)

        let keystoreImportService = KeystoreImportService(logger: Logger.shared)

        let interactor = AccountImportInteractor(
            accountOperationFactory: operationFactory,
            accountRepository: AnyDataProviderRepository(repository),
            operationManager: OperationManager(),
            settings: settings,
            keystoreImportService: keystoreImportService,
            eventCenter: eventCenter
        )

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

        let completeExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is SelectedAccountChanged {
                    completeExpectation.fulfill()
                }
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

        wait(for: [expectation, completeExpectation], timeout: Constants.defaultExpectationDuration)

        guard let selectedAccount = settings.value else {
            XCTFail("Unexpected empty account")
            return
        }

        XCTAssertEqual(selectedAccount.name, expectedUsername)

        let metaId = selectedAccount.metaId

        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.entropyTagForMetaId(metaId)))

        XCTAssertFalse(try keychain.checkKey(for: KeystoreTagV2.substrateDerivationTagForMetaId(metaId)))
        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.ethereumDerivationTagForMetaId(metaId)))

        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId)))
        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId)))

        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.substrateSeedTagForMetaId(metaId)))
        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.ethereumSeedTagForMetaId(metaId)))
    }
}
