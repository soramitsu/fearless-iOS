import XCTest
@testable import fearless
import SoraKeystore
import Cuckoo
import IrohaCrypto

class AccountConfirmTests: XCTestCase {

    func testMnemonicConfirm() throws {
        // given

        let view = MockAccountConfirmViewProtocol()
        let wireframe = MockAccountConfirmWireframeProtocol()

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let interactor = AccountConfirmInteractor(keychain: keychain,
                                                  settings: settings)

        let mnemonicWords = "great fog follow obtain oyster raw patient extend use mirror fix balance blame sudden vessel"

        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicWords)

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)

        let newAccountRequest = AccountCreationRequest(username: "myusername",
                                                       type: .kusamaMain,
                                                       derivationPath: "",
                                                       cryptoType: .sr25519)

        let operation = accountOperationFactory.newAccountOperation(request: newAccountRequest,
                                                                    mnemonic: mnemonic)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

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

        XCTAssertTrue(settings.accountConfirmed)
    }
}
