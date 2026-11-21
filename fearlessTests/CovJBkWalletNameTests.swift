import XCTest
import UIKit
import SoraFoundation
import SoraUI
@testable import fearless

final class CovJBkWalletNameView: CovJBkLoadableView, WalletNameViewInput {
    private(set) var inputViewModel: InputViewModelProtocol?
    func setInputViewModel(_ viewModel: InputViewModelProtocol) { inputViewModel = viewModel }
}

final class CovJBkWalletNameInteractor: WalletNameInteractorInput {
    private(set) weak var output: WalletNameInteractorOutput?
    private(set) var saved: [MetaAccountModel] = []

    func setup(with output: WalletNameInteractorOutput) { self.output = output }
    func save(wallet: MetaAccountModel) { saved.append(wallet) }
}

final class CovJBkWalletNameRouter: WalletNameRouterInput {
    private(set) var warnings: [String] = []
    private(set) var completions = 0
    private(set) var dismissals = 0
    private(set) var errors: [Error] = []

    func showWarningsScreen(walletName: String, from _: ControllerBackedProtocol?) { warnings.append(walletName) }
    func complete() { completions += 1 }
    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return true
    }
}

final class CovJBkWalletNameOutput: WalletNameViewOutput {
    private(set) var loads = 0
    private(set) var backs = 0
    private(set) var continues = 0

    func didLoad(view _: WalletNameViewInput) { loads += 1 }
    func didBackButtonTapped() { backs += 1 }
    func didContinueButtonTapped() { continues += 1 }
}

final class CovJBkWalletNamePresenterTests: XCTestCase {
    private struct Screen {
        let presenter: WalletNamePresenter
        let view: CovJBkWalletNameView
        let interactor: CovJBkWalletNameInteractor
        let router: CovJBkWalletNameRouter
    }

    private func makeScreen(mode: WalletNameScreenMode) throws -> Screen {
        let view = CovJBkWalletNameView()
        let interactor = CovJBkWalletNameInteractor()
        let router = CovJBkWalletNameRouter()
        let presenter = WalletNamePresenter(
            mode: mode,
            interactor: interactor,
            router: router,
            localizationManager: try CovJBkFixture.localization()
        )
        presenter.didLoad(view: view)
        return Screen(presenter: presenter, view: view, interactor: interactor, router: router)
    }

    func testNewWalletNameLeadsToTheRiskWarnings() throws {
        let screen = try makeScreen(mode: .create)
        let input = try XCTUnwrap(screen.view.inputViewModel)
        XCTAssertTrue(screen.interactor.output === screen.presenter)
        XCTAssertEqual(input.inputHandler.value, "")
        XCTAssertFalse(input.inputHandler.completed)

        input.inputHandler.changeValue(to: "Travel")
        screen.presenter.didContinueButtonTapped()
        screen.presenter.applyLocalization()

        XCTAssertEqual(screen.router.warnings, ["Travel"])
        XCTAssertEqual(screen.view.starts, 0)
        XCTAssertTrue(screen.interactor.saved.isEmpty)
    }

    func testEditingStartsFromTheCurrentNameAndSavesTheNewOne() throws {
        let wallet = CovJBkFixture.wallet(name: "Before")
        let screen = try makeScreen(mode: .editing(wallet))
        let input = try XCTUnwrap(screen.view.inputViewModel)
        XCTAssertEqual(input.inputHandler.value, "Before")

        input.inputHandler.changeValue(to: "After")
        screen.presenter.didContinueButtonTapped()

        XCTAssertEqual(screen.view.starts, 1)
        let saved = try XCTUnwrap(screen.interactor.saved.first)
        XCTAssertEqual(saved.name, "After")
        XCTAssertEqual(saved.metaId, wallet.metaId)
        XCTAssertTrue(screen.router.warnings.isEmpty)
    }

    func testSaveOutcomesCompleteOrShowTheError() throws {
        let wallet = CovJBkFixture.wallet()
        let screen = try makeScreen(mode: .editing(wallet))

        screen.presenter.didReceiveSaveOperation(result: .success(wallet))
        screen.presenter.didReceiveSaveOperation(result: .failure(CovJError("rename")))
        screen.presenter.didBackButtonTapped()

        XCTAssertEqual(screen.view.stops, 2)
        XCTAssertEqual(screen.router.completions, 1)
        XCTAssertEqual(screen.router.errors.first as? CovJError, CovJError("rename"))
        XCTAssertEqual(screen.router.dismissals, 1)
    }
}

final class CovJBkWalletNameControllerTests: XCTestCase {
    private var languages: [String]? { CovJBkFixture.languages }

    func testTypingEnablesContinueAndControlsAreForwarded() throws {
        let output = CovJBkWalletNameOutput()
        let controller = WalletNameViewController(mode: .create, output: output, localizationManager: try CovJBkFixture.localization())
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = controller.rootView
        let field = root.nameTextField.animatedInputField
        XCTAssertEqual(output.loads, 1)
        XCTAssertTrue(controller.animatedTextField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "x"))

        let handler = InputHandler(predicate: NSPredicate.notEmpty)
        controller.setInputViewModel(InputViewModel(inputHandler: handler))
        XCTAssertEqual(root.nameTextField.text, "")
        XCTAssertTrue(controller.animatedTextField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "Mine"))
        XCTAssertEqual(handler.value, "Mine")
        field.sendActions(for: .editingChanged)

        XCTAssertEqual(root.nameTextField.text, "Mine")
        XCTAssertTrue(root.continueButton.isEnabled)
        root.continueButton.sendActions(for: .touchUpInside)
        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.continues, 1)
        XCTAssertEqual(output.backs, 1)

        handler.changeValue(to: "")
        field.sendActions(for: .editingChanged)
        XCTAssertFalse(root.continueButton.isEnabled)
    }

    func testFocusFollowsAppearanceTapsAndReturn() throws {
        let controller = WalletNameViewController(
            mode: .editing(CovJBkFixture.wallet()),
            output: CovJBkWalletNameOutput(),
            localizationManager: try CovJBkFixture.localization()
        )
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = controller.rootView
        let field = root.nameTextField.animatedInputField

        controller.viewWillAppear(false)
        controller.viewDidAppear(false)
        XCTAssertTrue(root.nameTextField.backgroundView.isHighlighted)
        XCTAssertNotNil(controller.keyboardHandler)

        XCTAssertFalse(controller.animatedTextFieldShouldReturn(field))
        XCTAssertFalse(root.nameTextField.backgroundView.isHighlighted)
        field.sendActions(for: .touchUpInside)
        XCTAssertTrue(root.nameTextField.backgroundView.isHighlighted)

        XCTAssertNotNil(controller.target)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(250), UIConstants.bigOffset)
        controller.updateWhileKeyboardFrameChanging(.zero)
        controller.viewDidDisappear(false)
        XCTAssertNil(controller.keyboardHandler)
    }

    func testDisabledInputKeepsItsValueAndLocalizationTitlesTheMode() throws {
        let controller = WalletNameViewController(
            mode: .editing(CovJBkFixture.wallet()),
            output: CovJBkWalletNameOutput(),
            localizationManager: try CovJBkFixture.localization()
        )
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let field = controller.rootView.nameTextField.animatedInputField

        controller.setInputViewModel(InputViewModel(inputHandler: InputHandler(value: "Kept", enabled: false)))
        field.text = "Changed"
        let applied = controller.animatedTextField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "x")
        controller.applyLocalization()

        XCTAssertFalse(applied)
        XCTAssertEqual(field.text, "Kept")
        XCTAssertEqual(
            controller.rootView.navigationBar.titleLabel.text,
            R.string.localizable.backupWalletNameEditingTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(
            controller.rootView.continueButton.imageWithTitleView?.title,
            R.string.localizable.commonSave(preferredLanguages: languages)
        )
    }
}

final class CovJBkWalletNameRoutingTests: XCTestCase {
    func testWarningsScreenIsPushedWithTheName() throws {
        let host = try CovJHostedView()
        defer { host.close() }

        WalletNameRouter().showWarningsScreen(walletName: "Pushed", from: host)

        XCTAssertTrue(host.top is BackupRiskWarningsViewController)
        XCTAssertEqual(host.navigation.viewControllers.count, 2)
    }

    func testCompleteDismissesWhatTheActiveWindowPresents() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        host.navigation.present(UIViewController(), animated: false)
        XCTAssertNotNil(host.presented)
        let active = SceneWindowFinder.activeWindow()

        WalletNameRouter().complete()

        if active === host.window {
            XCTAssertTrue(CovJWait.until { host.presented == nil })
        } else {
            XCTAssertNotNil(host.presented, "Only the active window's root is dismissed")
        }
    }

    func testAssemblyBuildsBothModes() throws {
        let create = try XCTUnwrap(WalletNameAssembly.configureModule(with: nil))
        let edit = try XCTUnwrap(WalletNameAssembly.configureModule(with: CovJBkFixture.wallet()))

        XCTAssertTrue(create.view is WalletNameViewController)
        XCTAssertTrue(create.input is WalletNamePresenter)
        XCTAssertTrue(edit.view is WalletNameViewController)
    }
}

final class CovJBkWalletNameInteractorOutput: WalletNameInteractorOutput {
    private(set) var results: [Result<MetaAccountModel, Error>] = []
    func didReceiveSaveOperation(result: Result<MetaAccountModel, Error>) { results.append(result) }
}

final class CovJBkWalletNameInteractorTests: XCTestCase {
    private func makeInteractor() -> (WalletNameInteractor, CovJBkWalletNameInteractorOutput, CovJBkEventCenter, SelectedWalletSettings) {
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        let events = CovJBkEventCenter()
        let interactor = WalletNameInteractor(eventCenter: events, selectedWalletSettings: settings)
        let output = CovJBkWalletNameInteractorOutput()
        interactor.setup(with: output)
        return (interactor, output, events, settings)
    }

    func testRenamingAWalletThatIsNotStoredFails() {
        let (interactor, output, events, _) = makeInteractor()

        interactor.save(wallet: CovJBkFixture.wallet(name: "Nowhere"))

        XCTAssertTrue(CovJWait.until(timeout: 5) { output.results.count == 1 })
        guard case let .failure(error) = output.results.first else {
            return XCTFail("A missing wallet cannot be renamed")
        }
        guard case .missingValue = error as? PersistentValueSettingsError else {
            return XCTFail("Unexpected error \(error)")
        }
        XCTAssertTrue(events.events.isEmpty)
    }

    func testBlankNameIsRefusedForAStoredWallet() {
        let (interactor, output, events, settings) = makeInteractor()
        let wallet = CovJBkFixture.wallet(name: "Stored")
        var saved = false
        settings.save(value: wallet, runningCompletionIn: .main) { result in
            if case .success = result { saved = true }
        }
        XCTAssertTrue(CovJWait.until(timeout: 5) { saved })

        interactor.save(wallet: wallet.replacingName("   "))

        XCTAssertTrue(CovJWait.until(timeout: 5) { output.results.count == 1 })
        guard case let .failure(error) = output.results.first else {
            return XCTFail("A blank name is refused")
        }
        guard case .invalidWalletRecord = error as? MetaAccountMapperError else {
            return XCTFail("Unexpected error \(error)")
        }
        XCTAssertTrue(events.events.isEmpty)
    }
}
