import XCTest
@testable import fearless
import SoraKeystore
import Cuckoo

class StakingMainTests: XCTestCase {
    /*func testSuccessfullSetup() throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            keychain: keychain,
                                                            settings: settings)

        let eventCenter = MockEventCenterProtocol().applyingDefaultStub()

        let view = MockStakingMainViewProtocol()
        let wireframe = MockStakingMainWireframeProtocol()
        let interactor = StakingMainInteractor(

        let primitiveFactory = WalletPrimitiveFactory(keystore: keychain,
                                                      settings: settings)
        let viewModelFacade = StakingViewModelFacade(primitiveFactory: primitiveFactory)
        let presenter = StakingMainPresenter(viewModelFacade: viewModelFacade,
                                             logger: Logger.shared)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        let expectation = XCTestExpectation()

        stub(view) { stub in
            stub.didReceive(viewModel: any()).then { _ in
                expectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }*/
}
