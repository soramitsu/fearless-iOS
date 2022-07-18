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
        let interactor = AccountCreateInteractor(mnemonicCreator: mnemonicCreator)

        let usernameSetup = UsernameSetupModel(username: "myname")
        let presenter = AccountCreatePresenter(usernameSetup: usernameSetup,
                                               wireframe: wireframe,
                                               interactor: interactor,
                                               flow: .wallet)
        interactor.presenter = presenter
        presenter.view = view

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didCompleteCryptoTypeSelection().thenDoNothing()
            when(stub).didValidateSubstrateDerivationPath(any()).thenDoNothing()
            when(stub).didValidateEthereumDerivationPath(any()).thenDoNothing()
            when(stub).isSetup.get.thenReturn(false, true)
            when(stub).set(chainType: any()).thenDoNothing()
            when(stub).bind(substrateViewModel: any()).thenDoNothing()
            when(stub).setEthereumCrypto(model: any()).thenDoNothing()
            when(stub).bind(ethereumViewModel: any()).thenDoNothing()

            when(stub).set(mnemonic: any()).then { _ in
                setupExpectation.fulfill()
            }

            when(stub).setSelectedSubstrateCrypto(model: any()).thenDoNothing()
        }

        let expectation = XCTestExpectation()

        var receivedRequest: MetaAccountImportMnemonicRequest?

        stub(wireframe) { stub in
            when(stub).confirm(from: any(), flow: any()).then { (_, flow) in
                if case .wallet(let request) = flow {
                    receivedRequest = request
                    expectation.fulfill()
                }
            }
        }

        // when

        presenter.setup()

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        presenter.proceed()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(receivedRequest?.username, usernameSetup.username)
    }
}
