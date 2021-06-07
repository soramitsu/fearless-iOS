import XCTest
@testable import fearless
import Cuckoo
import FearlessUtils

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
        let viewModelFactory = SelectedValidatorsViewModelFactory(iconGenerator: PolkadotIconGenerator())

        let presenter = SelectedValidatorsPresenter(viewModelFactory: viewModelFactory, validators: validators, maxTargets: 16)

        presenter.view = view
        presenter.wireframe = wireframe

        // when

        let expectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(viewModel: any()).then { viewModel in
                XCTAssertEqual(self.validators.count, viewModel.itemViewModels.count)
                expectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}
