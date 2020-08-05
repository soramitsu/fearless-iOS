import XCTest
@testable import fearless
import Cuckoo
import SoraFoundation

class UsernameSetupTests: XCTestCase {

    func testSuccessfullUsernameInput() {
        // given

        let view = MockUsernameSetupViewProtocol()
        let wireframe = MockUsernameSetupWireframeProtocol()

        let presenter = UsernameSetupPresenter()
        presenter.view = view
        presenter.wireframe = wireframe

        let expectedName = "test name"

        var receivedViewModel: InputViewModelProtocol?
        var receivedName: String?

        let viewModelExpectation = XCTestExpectation()
        let proceedExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).set(viewModel: any()).then { viewModel in
                receivedViewModel = viewModel
                viewModelExpectation.fulfill()
            }
        }

        stub(wireframe) { stub in
            when(stub).proceed(from: any(), username: any()).then { (_, name) in
                receivedName = name

                proceedExpectation.fulfill()
            }

            when(stub).present(viewModel: any(),
                               style: any(),
                               from: any()).then { (viewModel, _, _) in
                viewModel.actions.first?.handler?()

            }
        }

        // when

        presenter.setup()

        // then

        wait(for: [viewModelExpectation], timeout: Constants.defaultExpectationDuration)

        // when

        guard
            let accepted = receivedViewModel?.inputHandler
                .didReceiveReplacement(expectedName, for: NSRange(location: 0, length: 0)), accepted else {
            XCTFail("Unexpected empty view model")
            return
        }

        presenter.proceed()

        // then

        wait(for: [proceedExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(expectedName, receivedName)
    }
}
