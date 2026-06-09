import XCTest
import UIKit
import FearlessFoundation
@testable import fearless

final class BackupWalletNameTests: XCTestCase {
    func testDidLoad_whenCreatingWallet_thenSetsUpInteractorAndProvidesInputViewModel() {
        let interactor = WalletNameInteractorInputSpy()
        let presenter = createPresenter(mode: .create, interactor: interactor)
        let view = WalletNameViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(view.inputViewModel?.inputHandler.value, "")
    }

    func testDidLoad_whenEditingWallet_thenPrefillsWalletName() {
        let wallet = AccountGenerator.generateMetaAccount().replacingName("Existing Wallet")
        let presenter = createPresenter(mode: .editing(wallet))
        let view = WalletNameViewSpy()

        presenter.didLoad(view: view)

        XCTAssertEqual(view.inputViewModel?.inputHandler.value, "Existing Wallet")
    }

    func testDidContinueButtonTapped_whenCreatingWallet_thenShowsWarningsScreen() {
        let router = WalletNameRouterSpy()
        let presenter = createPresenter(mode: .create, router: router)
        let view = WalletNameViewSpy()

        presenter.didLoad(view: view)
        view.inputViewModel?.inputHandler.changeValue(to: "New Backup")
        presenter.didContinueButtonTapped()

        XCTAssertEqual(router.warningWalletName, "New Backup")
        XCTAssertTrue(router.warningView === view)
    }

    func testDidContinueButtonTapped_whenEditingWallet_thenSavesRenamedWallet() {
        let wallet = AccountGenerator.generateMetaAccount().replacingName("Old")
        let interactor = WalletNameInteractorInputSpy()
        let presenter = createPresenter(mode: .editing(wallet), interactor: interactor)
        let view = WalletNameViewSpy()

        presenter.didLoad(view: view)
        view.inputViewModel?.inputHandler.changeValue(to: "Renamed")
        presenter.didContinueButtonTapped()

        XCTAssertEqual(view.didStartLoadingCallCount, 1)
        XCTAssertEqual(interactor.savedWallet?.metaId, wallet.metaId)
        XCTAssertEqual(interactor.savedWallet?.name, "Renamed")
    }

    func testDidReceiveSaveOperation_whenSuccess_thenStopsLoadingAndCompletes() {
        let router = WalletNameRouterSpy()
        let presenter = createPresenter(mode: .editing(AccountGenerator.generateMetaAccount()), router: router)
        let view = WalletNameViewSpy()

        presenter.didLoad(view: view)
        presenter.didReceiveSaveOperation(result: .success(AccountGenerator.generateMetaAccount()))

        XCTAssertEqual(view.didStopLoadingCallCount, 1)
        XCTAssertEqual(router.completeCallCount, 1)
    }

    func testDidReceiveSaveOperation_whenFailure_thenStopsLoadingAndPresentsError() {
        let router = WalletNameRouterSpy()
        let presenter = createPresenter(mode: .editing(AccountGenerator.generateMetaAccount()), router: router)
        let view = WalletNameViewSpy()

        presenter.didLoad(view: view)
        presenter.didReceiveSaveOperation(result: .failure(BackupWalletNameTestError.failure))

        XCTAssertEqual(view.didStopLoadingCallCount, 1)
        XCTAssertTrue(router.presentedError is BackupWalletNameTestError)
        XCTAssertTrue(router.errorView === view)
    }

    func testDidBackButtonTapped_whenViewLoaded_thenDismissesView() {
        let router = WalletNameRouterSpy()
        let presenter = createPresenter(router: router)
        let view = WalletNameViewSpy()

        presenter.didLoad(view: view)
        presenter.didBackButtonTapped()

        XCTAssertTrue(router.dismissedView === view)
    }

    private func createPresenter(
        mode: WalletNameScreenMode = .create,
        interactor: WalletNameInteractorInput = WalletNameInteractorInputSpy(),
        router: WalletNameRouterInput = WalletNameRouterSpy()
    ) -> WalletNamePresenter {
        WalletNamePresenter(
            mode: mode,
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared
        )
    }
}

private final class WalletNameViewSpy: WalletNameViewInput {
    let controller = UIViewController()
    let isSetup = false
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true
    private(set) var inputViewModel: InputViewModelProtocol?
    private(set) var didStartLoadingCallCount = 0
    private(set) var didStopLoadingCallCount = 0

    func setInputViewModel(_ viewModel: InputViewModelProtocol) {
        inputViewModel = viewModel
    }

    func didStartLoading() {
        didStartLoadingCallCount += 1
    }

    func didStopLoading() {
        didStopLoadingCallCount += 1
    }
}

private final class WalletNameInteractorInputSpy: WalletNameInteractorInput {
    private(set) weak var output: WalletNameInteractorOutput?
    private(set) var savedWallet: MetaAccountModel?

    func setup(with output: WalletNameInteractorOutput) {
        self.output = output
    }

    func save(wallet: MetaAccountModel) {
        savedWallet = wallet
    }
}

private final class WalletNameRouterSpy: WalletNameRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var warningView: ControllerBackedProtocol?
    private(set) weak var errorView: ControllerBackedProtocol?
    private(set) var warningWalletName: String?
    private(set) var completeCallCount = 0
    private(set) var presentedError: Error?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func showWarningsScreen(
        walletName: String,
        from view: ControllerBackedProtocol?
    ) {
        warningWalletName = walletName
        warningView = view
    }

    func complete() {
        completeCallCount += 1
    }

    func present(error: Error, from view: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        errorView = view
        return true
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

private enum BackupWalletNameTestError: Error {
    case failure
}
