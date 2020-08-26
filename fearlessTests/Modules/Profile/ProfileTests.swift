import XCTest
@testable import fearless
import FearlessUtils
import SoraKeystore
import SoraFoundation
import Cuckoo

class ProfileTests: XCTestCase {
    func testProfileSuccessfullyLoaded() throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            keychain: keychain,
                                                            settings: settings)

        let view = MockProfileViewProtocol()

        let userDetailsExpectation = XCTestExpectation()
        let optionsExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)

            when(stub).didLoad(userViewModel: any()).then { _ in
                userDetailsExpectation.fulfill()
            }

            when(stub).didLoad(optionViewModels: any()).then { _ in
                optionsExpectation.fulfill()
            }
        }

        let wireframe = MockProfileWireframeProtocol()

        let viewModelFactory = ProfileViewModelFactory(iconGenerator: PolkadotIconGenerator())

        let presenter = ProfilePresenter(viewModelFactory: viewModelFactory)

        let eventCenter = MockEventCenterProtocol()

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
        }

        let interactor = ProfileInteractor(settingsManager: settings,
                                           eventCenter: eventCenter,
                                           logger: Logger.shared)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        presenter.localizationManager = LocalizationManager.shared

        interactor.presenter = presenter

        // when

        presenter.setup()

        // then

        wait(for: [userDetailsExpectation, optionsExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
