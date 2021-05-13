import XCTest
@testable import fearless
import Cuckoo
import SoraFoundation

class UsernameSetupTests: XCTestCase {

    func testSuccessfullUsernameInput() {
        // given

        let view = MockUsernameSetupViewProtocol()
        let wireframe = MockUsernameSetupWireframeProtocol()

        let defaultChain = Chain.westend
        let interactor = UsernameSetupInteractor(
            supportedNetworkTypes: Chain.allCases,
            defaultNetwork: defaultChain
        )

        let presenter = UsernameSetupPresenter()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        let expectedModel = UsernameSetupModel(username: "test name", selectedNetwork: defaultChain)

        var receivedViewModel: InputViewModelProtocol?
        var resultModel: UsernameSetupModel?

        let inputViewModelExpectation = XCTestExpectation()
        let networkViewModelExpectation = XCTestExpectation()
        let proceedExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).setInput(viewModel: any()).then { viewModel in
                receivedViewModel = viewModel
                inputViewModelExpectation.fulfill()
            }

            when(stub).setSelectedNetwork(model: any()).then { _ in
                networkViewModelExpectation.fulfill()
            }
        }

        stub(wireframe) { stub in
            when(stub).proceed(from: any(), model: any()).then { (_, model) in
                resultModel = model

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

        wait(
            for: [inputViewModelExpectation, networkViewModelExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        // when

        guard
            let accepted = receivedViewModel?.inputHandler
                .didReceiveReplacement(
                    expectedModel.username,
                    for: NSRange(location: 0, length: 0)
                ), accepted else {
            XCTFail("Unexpected empty view model")
            return
        }

        presenter.proceed()

        // then

        wait(for: [proceedExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(expectedModel, resultModel)
    }
}
