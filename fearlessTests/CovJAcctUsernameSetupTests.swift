import XCTest
import UIKit
import SSFModels
import SoraFoundation
@testable import fearless

final class CovJAcctUsernameViewStub: UIViewController, UsernameSetupViewProtocol {
    var usernames: [SelectableViewModel<InputViewModelProtocol>] = []
    var chains: [UniqueChainViewModel] = []

    func bindUsername(viewModel: SelectableViewModel<InputViewModelProtocol>) { usernames.append(viewModel) }
    func bindUniqueChain(viewModel: UniqueChainViewModel) { chains.append(viewModel) }
}

final class CovJAcctUsernameWireframeStub: UsernameSetupWireframeProtocol {
    var alerts: [SheetAlertPresentableViewModel] = []
    var proceeds: [(AccountCreateFlow, UsernameSetupModel)] = []

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { alerts.append(viewModel) }
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { true }
    func proceed(from _: UsernameSetupViewProtocol?, flow: AccountCreateFlow, model: UsernameSetupModel) {
        proceeds.append((flow, model))
    }
}

final class CovJAcctUsernamePresenterSpy: UsernameSetupPresenterProtocol {
    var loads = 0
    var proceeds = 0
    func didLoad(view _: UsernameSetupViewProtocol) { loads += 1 }
    func proceed() { proceeds += 1 }
}

final class CovJAcctUsernamePresenterTests: XCTestCase {
    private var languages: [String]? { LocalizationManager.shared.selectedLocale.rLanguages }

    private func make(flow: AccountCreateFlow) -> (UsernameSetupPresenter, CovJAcctUsernameViewStub, CovJAcctUsernameWireframeStub) {
        let wireframe = CovJAcctUsernameWireframeStub()
        let presenter = UsernameSetupPresenter(wireframe: wireframe, flow: flow, localizationManager: LocalizationManager.shared)
        let view = CovJAcctUsernameViewStub()
        presenter.didLoad(view: view)
        return (presenter, view, wireframe)
    }

    func testWalletFlowAsksAboutScreenshotsThenProceedsWithTypedName() throws {
        let (presenter, view, wireframe) = make(flow: .wallet)
        let username = try XCTUnwrap(view.usernames.first)
        XCTAssertTrue(username.selectable)
        XCTAssertEqual(username.underlyingViewModel.inputHandler.value, "")
        XCTAssertTrue(view.chains.isEmpty)
        username.underlyingViewModel.inputHandler.changeValue(to: "Daily")

        presenter.proceed()

        let alert = try XCTUnwrap(wireframe.alerts.first)
        XCTAssertEqual(alert.title, R.string.localizable.commonNoScreenshotTitle(preferredLanguages: languages))
        XCTAssertEqual(alert.message, R.string.localizable.commonNoScreenshotMessage(preferredLanguages: languages))
        XCTAssertEqual(alert.actions.map(\.title), [R.string.localizable.commonOk(preferredLanguages: languages)])
        XCTAssertTrue(wireframe.proceeds.isEmpty)
        alert.actions.first?.handler?()
        XCTAssertEqual(wireframe.proceeds.first?.1, UsernameSetupModel(username: "Daily"))
        guard case .wallet? = wireframe.proceeds.first?.0 else { return XCTFail("Expected the wallet flow") }
        presenter.applyLocalization()
        XCTAssertEqual(view.usernames.count, 1)
    }

    func testChainFlowLocksNameAndShowsNetwork() throws {
        let meta = AccountGenerator.generateMetaAccount().replacingName("Treasury")
        let chain = CovJFixture.chain(name: "Kusama", icon: URL(string: "https://example.invalid/ksm.svg"))
        let (presenter, view, wireframe) = make(flow: .chain(model: UniqueChainModel(meta: meta, chain: chain)))
        let username = try XCTUnwrap(view.usernames.first)
        XCTAssertFalse(username.selectable)
        XCTAssertEqual(username.underlyingViewModel.inputHandler.value, "Treasury")
        XCTAssertEqual(view.chains.first?.text, "Kusama")
        XCTAssertNotNil(view.chains.first?.icon)

        presenter.proceed()
        try XCTUnwrap(wireframe.alerts.first).actions.first?.handler?()
        XCTAssertEqual(wireframe.proceeds.first?.1.username, "Treasury")
        guard case .chain? = wireframe.proceeds.first?.0 else { return XCTFail("Expected the chain flow") }

        let (_, backupView, _) = make(flow: .backup)
        XCTAssertEqual(backupView.usernames.first?.selectable, true)
    }
}

final class CovJAcctUsernameControllerTests: XCTestCase {
    private func make() throws -> (UsernameSetupViewController, CovJAcctUsernamePresenterSpy, UIWindow) {
        let presenter = CovJAcctUsernamePresenterSpy()
        let controller = UsernameSetupViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        return (controller, presenter, window)
    }

    func testBindingNameFieldAndActions() throws {
        let (controller, presenter, window) = try make()
        defer {
            controller.view.endEditing(true)
            window.isHidden = true
        }
        let root = controller.rootView
        let languages = LocalizationManager.shared.selectedLocale.rLanguages
        XCTAssertEqual(presenter.loads, 1)
        XCTAssertEqual(controller.title, R.string.localizable.onboardingCreateWallet(preferredLanguages: languages))

        let field = root.usernameTextField.animatedInputField
        XCTAssertTrue(controller.animatedTextField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "x"))

        let model = InputViewModel(inputHandler: InputHandler(predicate: .notEmpty, processor: ByteLengthProcessor.username))
        controller.bindUsername(viewModel: SelectableViewModel(underlyingViewModel: model, selectable: false))
        XCTAssertTrue(root.usernameTextFieldContainer.isHidden)
        XCTAssertTrue(root.hintLabelContainer.isHidden)
        XCTAssertFalse(root.nextButton.isEnabled)

        XCTAssertTrue(controller.animatedTextField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "Main"))
        XCTAssertEqual(model.inputHandler.value, "Main")
        field.text = "Main"
        XCTAssertFalse(controller.animatedTextField(
            field, shouldChangeCharactersIn: NSRange(location: 4, length: 0), replacementString: String(repeating: "z", count: 40)
        ))
        XCTAssertEqual(field.text, model.inputHandler.value)
        field.text = "stale"
        field.sendActions(for: .editingChanged)
        XCTAssertEqual(field.text, model.inputHandler.value)
        XCTAssertTrue(root.nextButton.isEnabled)
        XCTAssertFalse(controller.animatedTextFieldShouldReturn(field))

        controller.bindUsername(viewModel: SelectableViewModel(underlyingViewModel: model, selectable: true))
        XCTAssertFalse(root.usernameTextFieldContainer.isHidden)

        root.nextButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.proceeds, 1)
    }

    func testUniqueChainKeyboardAndLocalization() throws {
        let (controller, _, window) = try make()
        defer { window.isHidden = true }
        let root = controller.rootView
        let icon = CovJAcctImageStub()

        controller.bindUniqueChain(viewModel: UniqueChainViewModel(text: "Polkadot", icon: icon))
        XCTAssertFalse(root.chainViewContainer.isHidden)
        XCTAssertEqual(root.chainView.actionControl.contentView.subtitleLabelView.text, "Polkadot")
        XCTAssertEqual(icon.loads.count, 1)

        controller.viewDidLayoutSubviews()
        XCTAssertTrue(controller.shouldApplyKeyboardFrame)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(4), root.adaptiveEntry ? 0 : UIConstants.bigOffset)
        XCTAssertTrue(controller.target === root.keyboardAdoptableConstraint)
        root.contentView.scrollView.contentInset.bottom = 40
        controller.updateWhileKeyboardFrameChanging(CGRect(x: 0, y: 0, width: 390, height: 260))
        XCTAssertEqual(root.contentView.scrollView.contentInset.bottom, root.adaptiveEntry ? 0 : 40)
        if root.adaptiveEntry {
            root.handleKeyboard(frame: CGRect(x: 0, y: 0, width: 390, height: 260))
            XCTAssertEqual(root.keyboardAdoptableConstraint?.layoutConstraints.first?.constant, -260)
        }

        controller.applyLocalization()
        XCTAssertEqual(root.locale, LocalizationManager.shared.selectedLocale)
    }
}

final class CovJAcctUsernameRoutingTests: XCTestCase {
    private func onboarding<F: UsernameSetupViewFactoryProtocol>(_: F.Type) -> UsernameSetupViewProtocol? {
        F.createViewForOnboarding()
    }

    func testFactoriesBuildUsernameControllers() throws {
        let views = [
            UsernameSetupViewFactory.createViewForOnboarding(flow: .backup),
            UsernameSetupViewFactory.createViewForAdding(),
            UsernameSetupViewFactory.createViewForSwitch(),
            onboarding(UsernameSetupViewFactory.self)
        ]
        for view in views {
            let controller = try XCTUnwrap(view?.controller as? UsernameSetupViewController)
            XCTAssertFalse(controller.isViewLoaded)
        }
    }

    func testWireframesPushAccountCreation() throws {
        let wireframes: [UsernameSetupWireframeProtocol] = [
            UsernameSetupWireframe(), AddAccount.UsernameSetupWireframe(), SwitchAccount.UsernameSetupWireframe()
        ]
        for wireframe in wireframes {
            let host = try CovJHostedView(controller: CovJAcctUsernameViewStub())
            defer { host.close() }
            let view = try XCTUnwrap(host.controller as? CovJAcctUsernameViewStub)

            wireframe.proceed(from: view, flow: .wallet, model: UsernameSetupModel(username: "Next"))

            XCTAssertEqual(host.navigation.viewControllers.count, 2, "\(type(of: wireframe))")
            XCTAssertTrue(host.top is AccountCreateViewController, "\(type(of: wireframe))")
        }
    }
}
