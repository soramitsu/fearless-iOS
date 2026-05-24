import XCTest
import UIKit
import FearlessFoundation
import SSFCloudStorage
@testable import fearless

final class BackupSelectWalletTests: XCTestCase {
    func testDidLoad_whenAccountsProvided_thenSetsUpInteractorAndProvidesNames() {
        let interactor = BackupSelectWalletInteractorInputSpy()
        let presenter = createPresenter(
            accounts: [
                makeAccount(name: "Alice", address: "alice-address"),
                makeAccount(name: "Bob", address: "bob-address")
            ],
            interactor: interactor
        )
        let view = BackupSelectWalletViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(view.viewModels, ["Alice", "Bob"])
        XCTAssertEqual(interactor.fetchBackupAccountsCallCount, 0)
    }

    func testDidLoad_whenAccountsMissing_thenFetchesBackupAccounts() {
        let interactor = BackupSelectWalletInteractorInputSpy()
        let presenter = createPresenter(accounts: nil, interactor: interactor)
        let view = BackupSelectWalletViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(interactor.fetchBackupAccountsCallCount, 1)
        XCTAssertNil(view.viewModels)
    }

    func testViewDidAppear_whenAccountsMissing_thenStartsLoadingAndFetchesAgain() {
        let interactor = BackupSelectWalletInteractorInputSpy()
        let presenter = createPresenter(accounts: nil, interactor: interactor)
        let view = BackupSelectWalletViewSpy()

        presenter.didLoad(view: view)
        presenter.viewDidAppear()

        XCTAssertEqual(view.didStartLoadingCallCount, 1)
        XCTAssertEqual(interactor.fetchBackupAccountsCallCount, 2)
    }

    func testDidReceiveBackupAccounts_whenSuccess_thenStopsLoadingAndProvidesNames() {
        let interactor = BackupSelectWalletInteractorInputSpy()
        let presenter = createPresenter(accounts: nil, interactor: interactor)
        let view = BackupSelectWalletViewSpy()

        presenter.didLoad(view: view)
        presenter.didReceiveBackupAccounts(
            result: .success([
                makeAccount(name: "Primary", address: "primary-address"),
                makeAccount(name: nil, address: "unnamed-address")
            ])
        )

        XCTAssertEqual(view.didStopLoadingCallCount, 1)
        XCTAssertEqual(view.viewModels, ["Primary"])
    }

    func testDidReceiveBackupAccounts_whenFailure_thenShowsRetryAlert() {
        let interactor = BackupSelectWalletInteractorInputSpy()
        let router = BackupSelectWalletRouterSpy()
        let presenter = createPresenter(accounts: nil, interactor: interactor, router: router)
        let view = BackupSelectWalletViewSpy()

        presenter.didLoad(view: view)
        presenter.didReceiveBackupAccounts(result: .failure(BackupSelectWalletTestError.failure))
        router.presentedActions.first?.handler?()

        XCTAssertEqual(view.didStopLoadingCallCount, 1)
        XCTAssertEqual(router.presentedTitle, R.string.localizable.noAccessToGoogle())
        XCTAssertTrue(router.presentedView === view)
        XCTAssertEqual(router.presentedActions.map(\.title), [R.string.localizable.tryAgain()])
        XCTAssertEqual(interactor.fetchBackupAccountsCallCount, 2)
    }

    func testDidTap_whenAccountsProvided_thenRoutesToBackupPasswordWithSelectedAccount() {
        let router = BackupSelectWalletRouterSpy()
        let accounts = [
            makeAccount(name: "First", address: "first-address"),
            makeAccount(name: "Second", address: "second-address")
        ]
        let presenter = createPresenter(accounts: accounts, router: router)
        let view = BackupSelectWalletViewSpy()

        presenter.didLoad(view: view)
        presenter.didTap(on: IndexPath(row: 1, section: 0))

        XCTAssertEqual(router.backupAccounts.map { $0.account.address }, ["first-address", "second-address"])
        XCTAssertEqual(router.backupAccounts.map(\.current), [false, true])
        XCTAssertTrue(router.backupPasswordView === view)
    }

    func testUserNavigationActions_whenTriggered_thenRouteAndDisconnect() {
        let interactor = BackupSelectWalletInteractorInputSpy()
        let router = BackupSelectWalletRouterSpy()
        let presenter = createPresenter(interactor: interactor, router: router)
        let view = BackupSelectWalletViewSpy()

        presenter.didLoad(view: view)
        presenter.didBackButtonTapped()
        presenter.didCreateNewAccountButtonTapped()
        presenter.beingDismissed()

        XCTAssertTrue(router.dismissedView === view)
        XCTAssertTrue(router.walletNameView === view)
        XCTAssertEqual(interactor.disconnectCallCount, 1)
    }

    private func createPresenter(
        accounts: [OpenBackupAccount]? = [makeAccount(name: "Wallet", address: "wallet-address")],
        interactor: BackupSelectWalletInteractorInput = BackupSelectWalletInteractorInputSpy(),
        router: BackupSelectWalletRouterInput = BackupSelectWalletRouterSpy()
    ) -> BackupSelectWalletPresenter {
        BackupSelectWalletPresenter(
            accounts: accounts,
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared
        )
    }
}

private final class BackupSelectWalletViewSpy: BackupSelectWalletViewInput {
    let controller = UIViewController()
    let isSetup = false
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true
    private(set) var viewModels: [String]?
    private(set) var didStartLoadingCallCount = 0
    private(set) var didStopLoadingCallCount = 0

    func didReceive(viewModels: [String]) {
        self.viewModels = viewModels
    }

    func didStartLoading() {
        didStartLoadingCallCount += 1
    }

    func didStopLoading() {
        didStopLoadingCallCount += 1
    }
}

private final class BackupSelectWalletInteractorInputSpy: BackupSelectWalletInteractorInput {
    private(set) weak var output: BackupSelectWalletInteractorOutput?
    private(set) var fetchBackupAccountsCallCount = 0
    private(set) var disconnectCallCount = 0

    func setup(with output: BackupSelectWalletInteractorOutput) {
        self.output = output
    }

    func fetchBackupAccounts() {
        fetchBackupAccountsCallCount += 1
    }

    func disconnect() {
        disconnectCallCount += 1
    }
}

private final class BackupSelectWalletRouterSpy: BackupSelectWalletRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var backupPasswordView: ControllerBackedProtocol?
    private(set) weak var walletNameView: ControllerBackedProtocol?
    private(set) weak var presentedView: ControllerBackedProtocol?
    private(set) var backupAccounts: [BackupAccount] = []
    private(set) var presentedTitle: String?
    private(set) var presentedActions: [SheetAlertPresentableAction] = []
    private(set) var presentedError: Error?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func presentBackupPasswordScreen(
        for backupAccounts: [BackupAccount],
        from view: ControllerBackedProtocol?
    ) {
        self.backupAccounts = backupAccounts
        backupPasswordView = view
    }

    func showWalletNameScreen(from view: ControllerBackedProtocol?) {
        walletNameView = view
    }

    func present(error: Error, from view: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        presentedView = view
        return true
    }

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from view: ControllerBackedProtocol?
    ) {
        presentedTitle = viewModel.title
        presentedActions = viewModel.actions
        presentedView = view
    }

    func present(
        message _: String?,
        title: String,
        closeAction _: String?,
        from view: ControllerBackedProtocol?,
        actions: [SheetAlertPresentableAction]
    ) {
        presentedTitle = title
        presentedActions = actions
        presentedView = view
    }

    func presentInfo(
        message _: String?,
        title: String,
        from view: ControllerBackedProtocol?
    ) {
        presentedTitle = title
        presentedView = view
    }
}

private enum BackupSelectWalletTestError: Error {
    case failure
}

private func makeAccount(name: String?, address: String) -> OpenBackupAccount {
    OpenBackupAccount(name: name, address: address)
}
