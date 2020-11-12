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

        let mnemonicCreator = IRMnemonicCreator()
        let interactor = AccountCreateInteractor(mnemonicCreator: mnemonicCreator,
                                                 supportedAddressTypes: SNAddressType.supported,
                                                 defaultAddressType: ConnectionItem.defaultConnection.type)

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

        var receivedRequest: AccountCreationRequest?

        stub(wireframe) { stub in
            when(stub).confirm(from: any(), request: any(), metadata: any()).then { (_, request, _) in
                receivedRequest = request
                expectation.fulfill()
            }
        }

        // when

        presenter.setup()

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        presenter.proceed()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(receivedRequest?.username, expectedUsername)
    }
}
