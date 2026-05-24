import XCTest
@testable import FearlessFoundation

final class InputViewModelTests: XCTestCase {
    func testInit_whenOptionalValuesProvided_thenStoresInputConfiguration() {
        let handler = InputHandler(value: "sora")

        let viewModel = InputViewModel(
            inputHandler: handler,
            title: "Network",
            placeholder: "Enter network",
            autocapitalization: .none
        )

        XCTAssertEqual(viewModel.title, "Network")
        XCTAssertEqual(viewModel.placeholder, "Enter network")
        XCTAssertTrue(viewModel.inputHandler as AnyObject === handler)
        XCTAssertEqual(viewModel.autocapitalization, .none)
    }

    func testInit_whenOnlyHandlerProvided_thenUsesDefaultPresentationValues() {
        let handler = InputHandler()

        let viewModel = InputViewModel(inputHandler: handler)

        XCTAssertEqual(viewModel.title, "")
        XCTAssertEqual(viewModel.placeholder, "")
        XCTAssertTrue(viewModel.inputHandler as AnyObject === handler)
        XCTAssertEqual(viewModel.autocapitalization, .sentences)
    }
}
