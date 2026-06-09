import XCTest
import UIKit
@testable import fearless
import FearlessFoundation
import SSFModels

final class UsernameSetupTests: XCTestCase {
    func testDidLoad_whenWalletFlow_thenBindsSelectableEmptyUsername() {
        let view = UsernameSetupViewSpy()
        let presenter = createPresenter(flow: .wallet)

        presenter.didLoad(view: view)

        XCTAssertEqual(view.usernameViewModels.count, 1)
        XCTAssertTrue(view.usernameViewModels[0].selectable)
        XCTAssertEqual(view.usernameViewModels[0].underlyingViewModel.inputHandler.value, "")
        XCTAssertTrue(view.uniqueChainViewModels.isEmpty)
    }

    func testDidLoad_whenChainFlow_thenBindsLockedPredefinedUsernameAndUniqueChain() {
        let wallet = AccountGenerator.generateMetaAccount().replacingName("Chain Wallet")
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let view = UsernameSetupViewSpy()
        let presenter = createPresenter(
            flow: .chain(model: UniqueChainModel(meta: wallet, chain: chain))
        )

        presenter.didLoad(view: view)

        XCTAssertEqual(view.usernameViewModels.count, 1)
        XCTAssertFalse(view.usernameViewModels[0].selectable)
        XCTAssertEqual(view.usernameViewModels[0].underlyingViewModel.inputHandler.value, wallet.name)
        XCTAssertEqual(view.uniqueChainViewModels.map(\.text), [chain.name])
    }

    func testProceed_whenUserConfirmsWarning_thenRoutesWithEnteredUsername() {
        let view = UsernameSetupViewSpy()
        let wireframe = UsernameSetupWireframeSpy()
        let presenter = createPresenter(flow: .wallet, wireframe: wireframe)

        presenter.didLoad(view: view)
        let input = view.usernameViewModels[0].underlyingViewModel.inputHandler
        let accepted = input.didReceiveReplacement(
            "test name",
            for: NSRange(location: 0, length: input.value.count)
        )

        presenter.proceed()
        wireframe.presentedSheet?.actions.first?.handler?()

        XCTAssertTrue(accepted)
        XCTAssertEqual(wireframe.presentedSheetsCount, 1)
        XCTAssertEqual(wireframe.proceededModel, UsernameSetupModel(username: "test name"))
        XCTAssertTrue(wireframe.proceededFrom === view)

        guard case .wallet? = wireframe.proceededFlow else {
            XCTFail("Expected wallet flow")
            return
        }
    }

    private func createPresenter(
        flow: AccountCreateFlow,
        wireframe: UsernameSetupWireframeSpy = UsernameSetupWireframeSpy()
    ) -> UsernameSetupPresenter {
        UsernameSetupPresenter(
            wireframe: wireframe,
            flow: flow,
            localizationManager: LocalizationManagerStub()
        )
    }
}

private final class UsernameSetupViewSpy: UsernameSetupViewProtocol {
    let controller = UIViewController()
    var isSetup: Bool { controller.isViewLoaded }

    private(set) var usernameViewModels: [SelectableViewModel<InputViewModelProtocol>] = []
    private(set) var uniqueChainViewModels: [UniqueChainViewModel] = []

    func bindUsername(viewModel: SelectableViewModel<InputViewModelProtocol>) {
        usernameViewModels.append(viewModel)
    }

    func bindUniqueChain(viewModel: UniqueChainViewModel) {
        uniqueChainViewModels.append(viewModel)
    }
}

private final class UsernameSetupWireframeSpy: UsernameSetupWireframeProtocol {
    private(set) var presentedSheetsCount = 0
    private(set) var presentedSheet: SheetAlertPresentableViewModel?
    private(set) var proceededFrom: UsernameSetupViewProtocol?
    private(set) var proceededFlow: AccountCreateFlow?
    private(set) var proceededModel: UsernameSetupModel?

    func proceed(
        from view: UsernameSetupViewProtocol?,
        flow: AccountCreateFlow,
        model: UsernameSetupModel
    ) {
        proceededFrom = view
        proceededFlow = flow
        proceededModel = model
    }

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from view: ControllerBackedProtocol?
    ) {
        presentedSheetsCount += 1
        presentedSheet = viewModel
    }

    func present(
        message: String?,
        title: String,
        closeAction: String?,
        from view: ControllerBackedProtocol?,
        actions: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message: String?, title: String, from view: ControllerBackedProtocol?) {}

    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        false
    }
}

private final class LocalizationManagerStub: LocalizationManagerProtocol {
    var selectedLocalization = "en"
    let availableLocalizations = ["en"]

    func addObserver(
        with owner: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping LocalizationChangeClosure
    ) {}

    func removeObserver(by owner: AnyObject) {}
}
