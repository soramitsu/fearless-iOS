import XCTest
import Cuckoo
import RobinHood
import SoraFoundation
@testable import fearless

class StakingBalanceTests: XCTestCase {

    func testStakingBalanceActions() {
        let interactor = MockStakingBalanceInteractorInputProtocol()
        let wireframe = MockStakingBalanceWireframeProtocol()
        let presenter = StakingBalancePresenter(interactor: interactor, wireframe: wireframe)

        // given
        let showBondMoreExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).showBondMore(from: any()).then { _ in
                showBondMoreExpectation.fulfill()
            }
        }
        // when
        presenter.handleBondMoreAction()

        // then
        wait(for: [showBondMoreExpectation], timeout: Constants.defaultExpectationDuration)



        // given
        let showUnbondExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).showUnbond(from: any()).then { _ in
                showUnbondExpectation.fulfill()
            }
        }
        // when
        presenter.handleUnbondAction()

        // then
        wait(for: [showUnbondExpectation], timeout: Constants.defaultExpectationDuration)



        // given
        let showRedeemExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).showRedeem(from: any()).then { _ in
                showRedeemExpectation.fulfill()
            }
        }
        // when
        presenter.handleRedeemAction()

        // then
        wait(for: [showRedeemExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
