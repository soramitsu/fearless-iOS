import XCTest
@testable import fearless
import SoraKeystore
import IrohaCrypto
import RobinHood
import Cuckoo
import SoraFoundation

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
            when(stub.didCompleteCryptoTypeSelection()).thenDoNothing()
            when(stub.didValidateSubstrateDerivationPath(any(FieldStatus.self))).thenDoNothing()
            when(stub.didValidateEthereumDerivationPath(any(FieldStatus.self))).thenDoNothing()
            when(stub.isSetup.get).thenReturn(false, true)
            when(stub.set(chainType: any(AccountCreateChainType.self))).thenDoNothing()
            when(stub.bind(substrateViewModel: any(InputViewModelProtocol.self))).thenDoNothing()
            when(stub.setEthereumCrypto(model: any(TitleWithSubtitleViewModel.self))).thenDoNothing()
            when(stub.bind(ethereumViewModel: any(InputViewModelProtocol.self))).thenDoNothing()

            when(stub.set(mnemonic: any([String].self))).then { _ in
                setupExpectation.fulfill()
            }

            when(stub.setSelectedSubstrateCrypto(model: any(SelectableViewModel<TitleWithSubtitleViewModel>.self))).thenDoNothing()
        }

        let expectation = XCTestExpectation()

        var receivedRequest: MetaAccountImportMnemonicRequest?

        stub(wireframe) { stub in
            when(stub.confirm(from: any(AccountCreateViewProtocol?.self), flow: any(AccountConfirmFlow.self))).then { (_, flow) in
                if case .wallet(let request) = flow {
                    receivedRequest = request
                    expectation.fulfill()
                }
            }
        }

        // when

        presenter.setup()

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        presenter.proceed(withReplaced: nil)

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(receivedRequest?.username, usernameSetup.username)
    }

    func testSetupGeneratesTwentyFourWordMnemonic() {
        let presenter = MockAccountCreateInteractorOutputProtocol()
        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator())
        interactor.presenter = presenter

        let expectation = XCTestExpectation()

        stub(presenter) { stub in
            when(stub.didReceive(mnemonic: any([String].self))).then { mnemonic in
                XCTAssertEqual(mnemonic.count, 24)
                expectation.fulfill()
            }
            when(stub.didReceiveMnemonicGeneration(error: any(Error.self))).thenDoNothing()
        }

        interactor.setup()

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}
