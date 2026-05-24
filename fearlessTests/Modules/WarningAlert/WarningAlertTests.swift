import XCTest
import UIKit
@testable import fearless

final class WarningAlertTests: XCTestCase {
    func testDidLoad_whenViewIsProvided_thenPassesConfigToView() {
        let config = WarningAlertConfig(
            title: "Update required",
            iconImage: nil,
            text: "Install a supported app version.",
            buttonTitle: "Update",
            blocksUi: true
        )
        let view = WarningAlertViewSpy()
        let presenter = createPresenter(config: config)

        presenter.didLoad(view: view)

        XCTAssertEqual(view.receivedConfig?.title, config.title)
        XCTAssertEqual(view.receivedConfig?.text, config.text)
        XCTAssertEqual(view.receivedConfig?.buttonTitle, config.buttonTitle)
        XCTAssertEqual(view.receivedConfig?.blocksUi, config.blocksUi)
    }

    func testDidTapActionButton_whenTapped_thenRunsHandler() {
        var didRunHandler = false
        let presenter = createPresenter {
            didRunHandler = true
        }

        presenter.didTapActionButton()

        XCTAssertTrue(didRunHandler)
    }

    func testDidTapCloseButton_whenTapped_thenDismissesCurrentView() {
        let wireframe = WarningAlertWireframeSpy()
        let view = WarningAlertViewSpy()
        let presenter = createPresenter(wireframe: wireframe)

        presenter.didLoad(view: view)
        presenter.didTapCloseButton()

        XCTAssertTrue(wireframe.dismissedView === view)
    }

    private func createPresenter(
        config: WarningAlertConfig = WarningAlertConfig(
            title: "Title",
            iconImage: nil,
            text: "Text",
            buttonTitle: "Action",
            blocksUi: false
        ),
        wireframe: WarningAlertWireframeProtocol = WarningAlertWireframeSpy(),
        buttonHandler: @escaping WarningAlertButtonHandler = {}
    ) -> WarningAlertPresenter {
        WarningAlertPresenter(
            interactor: WarningAlertInteractorInputStub(),
            wireframe: wireframe,
            alertConfig: config,
            buttonHandler: buttonHandler
        )
    }
}

private final class WarningAlertViewSpy: WarningAlertViewProtocol {
    let controller = UIViewController()
    let isSetup = false
    private(set) var receivedConfig: WarningAlertConfig?

    func didReceive(config: WarningAlertConfig) {
        receivedConfig = config
    }
}

private final class WarningAlertWireframeSpy: WarningAlertWireframeProtocol {
    private(set) weak var dismissedView: ControllerBackedProtocol?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }
}

private final class WarningAlertInteractorInputStub: WarningAlertInteractorInputProtocol {}
