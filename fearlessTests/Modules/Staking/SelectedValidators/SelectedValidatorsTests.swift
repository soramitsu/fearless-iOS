import XCTest
@testable import fearless
import Cuckoo

class SelectedValidatorsTests: XCTestCase {
    let validators: [SelectedValidatorInfo] = {
        [
            SelectedValidatorInfo(address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6"),
            SelectedValidatorInfo(address: "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq")
        ]
    }()

    func testSetup() {
        // given

        let view = MockSelectedValidatorsViewProtocol()
        let wireframe = MockSelectedValidatorsWireframeProtocol()

        let presenter = SelectedValidatorsPresenter(validators: validators)

        presenter.view = view
        presenter.wireframe = wireframe

        // when

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(viewModels: any()).then { viewModels in
                XCTAssertEqual(self.validators.count, viewModels.count)
                expectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}
