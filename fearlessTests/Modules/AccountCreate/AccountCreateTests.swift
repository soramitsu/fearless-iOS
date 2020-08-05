import XCTest
@testable import fearless
import SoraKeystore
import IrohaCrypto
import RobinHood
import Cuckoo

class AccountCreateTests: XCTestCase {

    func testSuccessfullAccountCreation() {
        // given

        let view = MockAccountCreateViewProtocol()
        let wireframe = MockAccountCreateWireframeProtocol()

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let operationFactory = AccountOperationFactory(keystore: keychain,
                                                       settings: settings)
        let mnemonicCreator = IRMnemonicCreator()
        let interactor = AccountCreateInteractor(accountOperationFactory: operationFactory,
                                                 mnemonicCreator: mnemonicCreator,
                                                 operationManager: OperationManager())

        let expectedUsername = "myname"
        let presenter = AccountCreatePresenter(username: expectedUsername)
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didCompleteCryptoTypeSelection().thenDoNothing()
            when(stub).didCompleteNetworkTypeSelection().thenDoNothing()
            when(stub).didValidateDerivationPath(any()).thenDoNothing()
            when(stub).isSetup.get.thenReturn(false, true)

            when(stub).set(mnemonic: any()).then { _ in
                setupExpectation.fulfill()
            }

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

        presenter.proceed()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)

        guard let selectedAccount = settings.selectedAccount else {
            XCTFail("Unexpected empty account")
            return
        }

        XCTAssertEqual(selectedAccount.username, expectedUsername)

        XCTAssertTrue(try keychain.checkSeedForAddress(selectedAccount.address))
        XCTAssertTrue(try keychain.checkEntropyForAddress(selectedAccount.address))
        XCTAssertFalse(try keychain.checkDeriviationForAddress(selectedAccount.address))
    }
}
