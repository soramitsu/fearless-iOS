import XCTest
@testable import fearless
import SoraKeystore
import Cuckoo

class PincodeSetupTests: XCTestCase {

    func testSuccessfullPincodeSetup() {
        // given

        let view = MockPinSetupViewProtocol()
        let wireframe = MockPinSetupWireframeProtocol()

        let keystore = MockSecretStoreManagerProtocol()
        let biometry = MockBiometryAuthProtocol()
        let settings = InMemorySettingsManager()

        let interactor = PinSetupInteractor(secretManager: keystore,
                                            settingsManager: settings,
                                            biometryAuth: biometry)

        let presenter = PinSetupPresenter()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        let expectedPin = "123456"
        var savedPin: String?

        stub(keystore) { stub in
            when(stub).saveSecret(any(), for: any(), completionQueue: any(), completionBlock: any()).then {
                (secret, _, _, completion) in

                savedPin = secret.toUTF8String()

                completion(true)
            }
        }

        stub(biometry) { stub in
            when(stub).availableBiometryType.get.thenReturn(.none)
        }

        stub(view) { stub in
            when(stub).didChangeAccessoryState(enabled: any()).thenDoNothing()
        }

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).showMain(from: any()).then { _ in
                expectation.fulfill()
            }
        }

        // when

        presenter.start()
        presenter.submit(pin: expectedPin)

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)

        // then

        XCTAssertEqual(expectedPin, savedPin)
        XCTAssertNil(settings.biometryEnabled)
    }
}
