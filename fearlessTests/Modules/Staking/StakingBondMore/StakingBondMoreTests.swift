import XCTest
import Cuckoo
import RobinHood
import SoraFoundation
@testable import fearless

class StakingBondMoreTests: XCTestCase {

    func testContinueAction() {
        let wireframe = MockStakingBondMoreWireframeProtocol()
        let interactor = MockStakingBondMoreInteractorInputProtocol()
        let viewModelFactory = MockStakingBondMoreViewModelFactoryProtocol()
        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory
        )

        // given
        let continueExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).showConfirmation(from: any()).then { _ in
                continueExpectation.fulfill()
            }
        }

        // when
        presenter.handleContinueAction()

        // then
        wait(for: [continueExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
