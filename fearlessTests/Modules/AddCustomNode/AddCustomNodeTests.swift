import XCTest
import UIKit
import FearlessFoundation
@testable import fearless

final class AddCustomNodeTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenProvidesInputViewModels() {
        let presenter = createPresenter()
        let view = AddCustomNodeViewSpy()

        presenter.didLoad(view: view)

        XCTAssertNotNil(view.nameViewModel)
        XCTAssertNotNil(view.nodeViewModel)
    }

    func testDidTapAddNodeButton_whenInputsAreValid_thenAddsConnection() {
        let interactor = AddCustomNodeInteractorInputSpy()
        let presenter = createPresenter(interactor: interactor)
        let view = AddCustomNodeViewSpy()

        presenter.didLoad(view: view)
        view.nameViewModel?.inputHandler.changeValue(to: "Sora Node")
        view.nodeViewModel?.inputHandler.changeValue(to: "wss://node.example")
        presenter.didTapAddNodeButton()

        XCTAssertEqual(interactor.addedURL?.absoluteString, "wss://node.example")
        XCTAssertEqual(interactor.addedName, "Sora Node")
    }

    func testDidTapAddNodeButton_whenInputsAreInvalid_thenDoesNotAddConnection() {
        let interactor = AddCustomNodeInteractorInputSpy()
        let presenter = createPresenter(interactor: interactor)
        let view = AddCustomNodeViewSpy()

        presenter.didLoad(view: view)
        view.nameViewModel?.inputHandler.changeValue(to: "")
        view.nodeViewModel?.inputHandler.changeValue(to: "https://not-websocket.example")
        presenter.didTapAddNodeButton()

        XCTAssertNil(interactor.addedURL)
        XCTAssertNil(interactor.addedName)
    }

    func testDidTapCloseButton_whenViewAssigned_thenDismissesView() {
        let wireframe = AddCustomNodeWireframeSpy()
        let presenter = createPresenter(wireframe: wireframe)
        let view = AddCustomNodeViewSpy()

        presenter.view = view
        presenter.didTapCloseButton()

        XCTAssertTrue(wireframe.dismissedView === view)
    }

    func testAddingCallbacks_whenSuccessful_thenUpdatesLoadingStateNotifiesOutputAndDismisses() {
        let wireframe = AddCustomNodeWireframeSpy()
        let moduleOutput = AddCustomNodeModuleOutputSpy()
        let presenter = createPresenter(wireframe: wireframe, moduleOutput: moduleOutput)
        let view = AddCustomNodeViewSpy()
        let url = URL(string: "wss://node.example")!

        presenter.view = view
        presenter.didStartAdding(url: url)
        presenter.didCompleteAdding(url: url)

        XCTAssertEqual(view.didStartLoadingCallCount, 1)
        XCTAssertEqual(view.didStopLoadingCallCount, 1)
        XCTAssertEqual(moduleOutput.didChangedNodesListCallCount, 1)
        XCTAssertTrue(wireframe.dismissedView === view)
    }

    func testDidReceiveError_whenSpecificErrorNotPresented_thenPresentsFallbackError() {
        let wireframe = AddCustomNodeWireframeSpy(shouldPresentError: false)
        let presenter = createPresenter(wireframe: wireframe)
        let view = AddCustomNodeViewSpy()

        presenter.view = view
        presenter.didReceiveError(
            error: AddCustomNodeTestError.failure,
            for: URL(string: "wss://node.example")!
        )

        XCTAssertEqual(view.didStopLoadingCallCount, 1)
        XCTAssertEqual(wireframe.presentedErrors.count, 2)
        XCTAssertTrue(wireframe.presentedErrors.first is AddCustomNodeTestError)
        XCTAssertTrue(wireframe.presentedErrors.last is CommonError)
    }

    private func createPresenter(
        interactor: AddCustomNodeInteractorInputProtocol = AddCustomNodeInteractorInputSpy(),
        wireframe: AddCustomNodeWireframeProtocol = AddCustomNodeWireframeSpy(),
        moduleOutput: AddCustomNodeModuleOutput? = nil
    ) -> AddCustomNodePresenter {
        AddCustomNodePresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            moduleOutput: moduleOutput
        )
    }
}

private final class AddCustomNodeViewSpy: AddCustomNodeViewProtocol {
    let controller = UIViewController()
    let isSetup = false
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true
    private(set) var nameViewModel: InputViewModelProtocol?
    private(set) var nodeViewModel: InputViewModelProtocol?
    private(set) var didStartLoadingCallCount = 0
    private(set) var didStopLoadingCallCount = 0

    func didReceive(nameViewModel: InputViewModelProtocol) {
        self.nameViewModel = nameViewModel
    }

    func didReceive(nodeViewModel: InputViewModelProtocol) {
        self.nodeViewModel = nodeViewModel
    }

    func didStartLoading() {
        didStartLoadingCallCount += 1
    }

    func didStopLoading() {
        didStopLoadingCallCount += 1
    }
}

private final class AddCustomNodeInteractorInputSpy: AddCustomNodeInteractorInputProtocol {
    private(set) var addedURL: URL?
    private(set) var addedName: String?

    func addConnection(url: URL, name: String) {
        addedURL = url
        addedName = name
    }
}

private final class AddCustomNodeWireframeSpy: AddCustomNodeWireframeProtocol {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) var presentedErrors: [Error] = []
    private let shouldPresentError: Bool

    init(shouldPresentError: Bool = true) {
        self.shouldPresentError = shouldPresentError
    }

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedErrors.append(error)
        return shouldPresentError
    }

    func present(
        viewModel _: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(
        message _: String?,
        title _: String,
        from _: ControllerBackedProtocol?
    ) {}
}

private final class AddCustomNodeModuleOutputSpy: AddCustomNodeModuleOutput {
    private(set) var didChangedNodesListCallCount = 0

    func didChangedNodesList() {
        didChangedNodesListCallCount += 1
    }
}

private enum AddCustomNodeTestError: Error {
    case failure
}
