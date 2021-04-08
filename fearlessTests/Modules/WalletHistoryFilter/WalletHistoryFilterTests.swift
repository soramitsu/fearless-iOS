import XCTest
@testable import fearless
import Cuckoo

class WalletHistoryFilterTests: XCTestCase {

    func testSetup() {
        // given

        let view = MockWalletHistoryFilterViewProtocol()
        let wireframe = MockWalletHistoryFilterWireframeProtocol()

        let presenter = WalletHistoryFilterPresenter(filter: .transfers)
        presenter.view = view
        presenter.wireframe = wireframe

        // when

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(viewModel: any()).then { viewModel in
                XCTAssertTrue(viewModel.items[WalletHistoryFilterRow.transfers.rawValue].isOn)
                XCTAssertFalse(viewModel.items[WalletHistoryFilterRow.rewardsAndSlashes.rawValue].isOn)
                XCTAssertFalse(viewModel.items[WalletHistoryFilterRow.rewardsAndSlashes.rawValue].isOn)

                setupExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
