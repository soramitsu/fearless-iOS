import XCTest
@testable import fearless
import SoraFoundation
import Cuckoo

class NetworkInfoTests: XCTestCase {
    func testCopyAddress() {
        // given

        let view = MockNetworkInfoViewProtocol()
        let wireframe = MockNetworkInfoWireframeProtocol()

        let connectionItem = ConnectionItem.defaultConnection
        let presenter = NetworkInfoPresenter(connectionItem: connectionItem,
                                             readOnly: true,
                                             localizationManager: LocalizationManager.shared)

        let interactor = NetworkInfoInteractor()

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        let nameExpectation = XCTestExpectation()
        let nodeExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)
            when(stub).set(nameViewModel: any()).then { _ in
                nameExpectation.fulfill()
            }
            when(stub).set(nodeViewModel: any()).then { _ in
                nodeExpectation.fulfill()
            }
        }

        let copyExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            stub.presentSuccessNotification(any(), from: any()).then { _ in
                copyExpectation.fulfill()
            }
        }

        // when

        presenter.setup()

        // then

        wait(for: [nameExpectation, nodeExpectation], timeout: Constants.defaultExpectationDuration)

        // when

        presenter.activateCopy()

        // then

        wait(for: [copyExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
