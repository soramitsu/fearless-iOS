import XCTest
@testable import fearless
import SoraKeystore
import Cuckoo
import IrohaCrypto
import RobinHood

class AccountConfirmTests: XCTestCase {

    func testMnemonicConfirm() throws {
        // given

        let view = MockAccountConfirmViewProtocol()
        let wireframe = MockAccountConfirmWireframeProtocol()

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let mnemonicWords = "great fog follow obtain oyster raw patient extend use mirror fix balance blame sudden vessel"

        let newAccountRequest = AccountCreationRequest(username: "myusername",
                                                       type: .kusamaMain,
                                                       derivationPath: "",
                                                       cryptoType: .sr25519)

        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicWords)

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)

        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageTestFacade().createRepository()

        let interactor = AccountConfirmInteractor(request: newAccountRequest,
                                                  mnemonic: mnemonic,
                                                  accountOperationFactory: accountOperationFactory,
                                                  accountRepository: AnyDataProviderRepository(repository),
                                                  settings: settings,
                                                  operationManager: OperationManager())

        let presenter = AccountConfirmPresenter()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(words: any(), afterConfirmationFail: any()).then { _ in
                setupExpectation.fulfill()
            }
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

        presenter.confirm(words: mnemonic.allWords())

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)

        guard let selectedAccount = settings.selectedAccount else {
            XCTFail("Unexpected empty account")
            return
        }

        XCTAssertEqual(selectedAccount.username, newAccountRequest.username)

        XCTAssertTrue(try keychain.checkSecretKeyForAddress(selectedAccount.address))
        XCTAssertTrue(try keychain.checkEntropyForAddress(selectedAccount.address))
        XCTAssertFalse(try keychain.checkDeriviationForAddress(selectedAccount.address))
    }
}
