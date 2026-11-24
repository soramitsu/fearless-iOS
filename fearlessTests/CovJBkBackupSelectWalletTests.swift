import XCTest
import UIKit
import SoraFoundation
import SSFCloudStorage
@testable import fearless

final class CovJBkSelectWalletView: CovJBkLoadableView, BackupSelectWalletViewInput {
    private(set) var lists: [[String]] = []
    func didReceive(viewModels: [String]) { lists.append(viewModels) }
}

final class CovJBkSelectWalletInteractor: BackupSelectWalletInteractorInput {
    private(set) weak var output: BackupSelectWalletInteractorOutput?
    private(set) var fetches = 0
    private(set) var disconnects = 0

    func setup(with output: BackupSelectWalletInteractorOutput) { self.output = output }
    func fetchBackupAccounts() { fetches += 1 }
    func disconnect() { disconnects += 1 }
}

final class CovJBkSelectWalletRouter: BackupSelectWalletRouterInput {
    private(set) var passwordScreens: [[BackupAccount]] = []
    private(set) var walletNameScreens = 0
    private(set) var dismissals = 0
    private(set) var messages: [(title: String, message: String?, actions: [SheetAlertPresentableAction])] = []

    func presentBackupPasswordScreen(for backupAccounts: [BackupAccount], from _: ControllerBackedProtocol?) {
        passwordScreens.append(backupAccounts)
    }

    func showWalletNameScreen(from _: ControllerBackedProtocol?) { walletNameScreens += 1 }
    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(
        message: String?,
        title: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions: [SheetAlertPresentableAction]
    ) {
        messages.append((title, message, actions))
    }

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { true }
}

final class CovJBkSelectWalletOutput: BackupSelectWalletViewOutput {
    private(set) var loads = 0
    private(set) var taps: [IndexPath] = []
    private(set) var backs = 0
    private(set) var creates = 0
    private(set) var appears = 0
    private(set) var dismissed = 0

    func didLoad(view _: BackupSelectWalletViewInput) { loads += 1 }
    func didTap(on indexPath: IndexPath) { taps.append(indexPath) }
    func didBackButtonTapped() { backs += 1 }
    func didCreateNewAccountButtonTapped() { creates += 1 }
    func viewDidAppear() { appears += 1 }
    func beingDismissed() { dismissed += 1 }
}

final class CovJBkSelectWalletInteractorOutput: BackupSelectWalletInteractorOutput {
    private(set) var results: [Result<[OpenBackupAccount], Error>] = []
    func didReceiveBackupAccounts(result: Result<[OpenBackupAccount], Error>) { results.append(result) }
}

final class CovJBkBackupSelectWalletPresenterTests: XCTestCase {
    private var languages: [String]? { CovJBkFixture.languages }

    private struct Screen {
        let presenter: BackupSelectWalletPresenter
        let view: CovJBkSelectWalletView
        let interactor: CovJBkSelectWalletInteractor
        let router: CovJBkSelectWalletRouter
    }

    private func makeScreen(accounts: [OpenBackupAccount]?) throws -> Screen {
        let view = CovJBkSelectWalletView()
        let interactor = CovJBkSelectWalletInteractor()
        let router = CovJBkSelectWalletRouter()
        let presenter = BackupSelectWalletPresenter(
            accounts: accounts,
            interactor: interactor,
            router: router,
            localizationManager: try CovJBkFixture.localization()
        )
        presenter.didLoad(view: view)
        return Screen(presenter: presenter, view: view, interactor: interactor, router: router)
    }

    func testKnownBackupsAreListedByNameWithoutAskingDrive() throws {
        let screen = try makeScreen(accounts: [
            OpenBackupAccount(name: "First", address: "5First"),
            OpenBackupAccount(address: "5Unnamed"),
            OpenBackupAccount(name: "Third", address: "5Third")
        ])

        screen.presenter.viewDidAppear()
        screen.presenter.applyLocalization()

        XCTAssertTrue(screen.interactor.output === screen.presenter)
        XCTAssertEqual(screen.view.lists, [["First", "Third"]])
        XCTAssertEqual(screen.interactor.fetches, 0)
        XCTAssertEqual(screen.view.starts, 0)
    }

    func testUnknownBackupsAreFetchedOnLoadAndOnAppearance() throws {
        let screen = try makeScreen(accounts: nil)
        XCTAssertEqual(screen.interactor.fetches, 1)

        screen.presenter.viewDidAppear()
        XCTAssertEqual(screen.view.starts, 1)
        XCTAssertEqual(screen.interactor.fetches, 2)

        screen.presenter.didReceiveBackupAccounts(result: .success([OpenBackupAccount(name: "Found", address: "5Found")]))
        XCTAssertEqual(screen.view.stops, 1)
        XCTAssertEqual(screen.view.lists, [["Found"]])

        screen.presenter.viewDidAppear()
        XCTAssertEqual(screen.interactor.fetches, 2, "Fetched backups are not fetched again")
    }

    func testDriveFailureOffersARetry() throws {
        let screen = try makeScreen(accounts: nil)

        screen.presenter.didReceiveBackupAccounts(result: .failure(CovJError("drive")))

        XCTAssertEqual(screen.view.stops, 1)
        let message = try XCTUnwrap(screen.router.messages.last)
        XCTAssertEqual(message.title, R.string.localizable.noAccessToGoogle(preferredLanguages: languages))
        XCTAssertNil(message.message)
        XCTAssertEqual(message.actions.map(\.title), [R.string.localizable.tryAgain(preferredLanguages: languages)])
        message.actions.first?.handler?()
        XCTAssertEqual(screen.interactor.fetches, 2)
    }

    func testTappedBackupIsMarkedCurrentForThePasswordScreen() throws {
        let screen = try makeScreen(accounts: [
            OpenBackupAccount(name: "A", address: "5A"),
            OpenBackupAccount(name: "B", address: "5B")
        ])

        screen.presenter.didTap(on: IndexPath(row: 1, section: 0))

        let accounts = try XCTUnwrap(screen.router.passwordScreens.first)
        XCTAssertEqual(accounts.map(\.account.address), ["5A", "5B"])
        XCTAssertEqual(accounts.map(\.current), [false, true])
    }

    func testTapBeforeBackupsArriveDoesNothing() throws {
        let screen = try makeScreen(accounts: nil)

        screen.presenter.didTap(on: IndexPath(row: 0, section: 0))

        XCTAssertTrue(screen.router.passwordScreens.isEmpty)
    }

    func testNavigationActionsAndDismissalAreForwarded() throws {
        let screen = try makeScreen(accounts: [])

        screen.presenter.didBackButtonTapped()
        screen.presenter.didCreateNewAccountButtonTapped()
        screen.presenter.beingDismissed()

        XCTAssertEqual(screen.router.dismissals, 1)
        XCTAssertEqual(screen.router.walletNameScreens, 1)
        XCTAssertEqual(screen.interactor.disconnects, 1)
        XCTAssertEqual(screen.view.lists, [[]])
    }
}

final class CovJBkBackupSelectWalletInteractorTests: XCTestCase {
    func testFetchingSignsOutFirstAndListsDriveBackups() throws {
        let interactor = BackupSelectWalletInteractor()
        let cloud = CovJBkCloudStorage()
        cloud.accountsResult = .success([OpenBackupAccount(name: "Drive", address: "5Drive")])
        interactor.cloudStorageService = cloud
        let output = CovJBkSelectWalletInteractorOutput()
        interactor.setup(with: output)

        interactor.fetchBackupAccounts()

        XCTAssertTrue(CovJWait.until { output.results.count == 1 })
        XCTAssertEqual(try XCTUnwrap(output.results.first).get().map(\.address), ["5Drive"])
        XCTAssertEqual(cloud.calls, ["disconnect", "list"])
    }

    func testFailedListingDisconnectsAgainAndIsReported() {
        let interactor = BackupSelectWalletInteractor()
        let cloud = CovJBkCloudStorage()
        cloud.accountsResult = .failure(CloudStorageServiceError.notAuthorized)
        interactor.cloudStorageService = cloud
        let output = CovJBkSelectWalletInteractorOutput()
        interactor.setup(with: output)

        interactor.fetchBackupAccounts()

        XCTAssertTrue(CovJWait.until { output.results.count == 1 })
        if case let .failure(error) = output.results.first {
            XCTAssertEqual(error as? CloudStorageServiceError, .notAuthorized)
        } else {
            XCTFail("Listing failed")
        }
        XCTAssertEqual(cloud.calls, ["disconnect", "list", "disconnect"])
    }

    func testDisconnectAndMissingStorage() {
        let interactor = BackupSelectWalletInteractor()
        let output = CovJBkSelectWalletInteractorOutput()
        interactor.setup(with: output)
        interactor.fetchBackupAccounts()
        interactor.disconnect()
        CovJWait.drain(0.2)
        XCTAssertTrue(output.results.isEmpty)

        let cloud = CovJBkCloudStorage()
        interactor.cloudStorageService = cloud
        interactor.disconnect()
        XCTAssertEqual(cloud.calls, ["disconnect"])
    }
}

final class CovJBkBackupSelectWalletControllerTests: XCTestCase {
    private var languages: [String]? { CovJBkFixture.languages }

    private func makeController(_ output: CovJBkSelectWalletOutput) throws -> BackupSelectWalletViewController {
        BackupSelectWalletViewController(output: output, localizationManager: try CovJBkFixture.localization())
    }

    func testBackupNamesAreListedAndControlsForwarded() throws {
        let output = CovJBkSelectWalletOutput()
        let controller = try makeController(output)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let table = controller.rootView.tableView

        controller.didReceive(viewModels: ["One", "Two"])
        table.layoutIfNeeded()

        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(controller.viewModels, ["One", "Two"])
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertNotNil(table.cellForRow(at: IndexPath(row: 1, section: 0)) as? BackupSelectWalletTableCell)
        let cell = BackupSelectWalletTableCell(style: .default, reuseIdentifier: nil)
        controller.tableView(table, willDisplay: cell, forRowAt: IndexPath(row: 1, section: 0))
        XCTAssertTrue(CovJViewFixture.descendants(UILabel.self, in: cell).contains { $0.text == "Two" })
        controller.tableView(table, willDisplay: UITableViewCell(), forRowAt: IndexPath(row: 0, section: 0))

        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        controller.rootView.createButton.sendActions(for: .touchUpInside)
        let appearances = output.appears
        controller.viewDidAppear(false)
        controller.viewDidDisappear(false)

        XCTAssertEqual(output.taps, [IndexPath(row: 0, section: 0)])
        XCTAssertEqual(output.backs, 1)
        XCTAssertEqual(output.creates, 1)
        XCTAssertEqual(output.appears, appearances + 1)
        XCTAssertEqual(output.dismissed, 0, "Disappearing without a dismissal keeps Google signed in")
    }

    func testEmptyListShowsTheNotFoundState() throws {
        let controller = try makeController(CovJBkSelectWalletOutput())
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }

        controller.didReceive(viewModels: [])
        controller.applyLocalization()

        XCTAssertTrue(controller.shouldDisplayEmptyState)
        XCTAssertTrue(controller.contentViewForEmptyState === controller.rootView.container)
        XCTAssertTrue(controller.emptyStateDelegate === controller)
        XCTAssertTrue((controller.emptyStateDataSource as? BackupSelectWalletViewController) === controller)
        let empty = try XCTUnwrap(controller.viewForEmptyState as? EmptyView)
        XCTAssertEqual(empty.title, R.string.localizable.emptyViewTitle(preferredLanguages: languages))
        XCTAssertEqual(empty.text, R.string.localizable.importWalletsNotFound(preferredLanguages: languages))
        XCTAssertEqual(
            controller.rootView.navigationBar.titleLabel.text,
            R.string.localizable.backupSelectWalletTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(
            controller.rootView.createButton.imageWithTitleView?.title,
            R.string.localizable.backupSelectWalletCreateButton(preferredLanguages: languages)
        )
    }

    func testDismissingTheModalAsksToDisconnect() throws {
        let output = CovJBkSelectWalletOutput()
        let controller = try makeController(output)
        let host = try CovJHostedView()
        defer { host.close() }
        let navigation = UINavigationController(rootViewController: controller)
        host.controller.present(navigation, animated: false)
        XCTAssertTrue(CovJWait.until { controller.isViewLoaded && output.loads == 1 })

        navigation.dismiss(animated: true)

        XCTAssertTrue(CovJWait.until(timeout: 3) { output.dismissed == 1 })
    }

    func testCellShowsTheBoundName() {
        let cell = BackupSelectWalletTableCell(style: .default, reuseIdentifier: "covjbk")
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 88)

        cell.bind(name: "Bound")
        cell.layoutIfNeeded()

        XCTAssertEqual(cell.selectionStyle, .none)
        XCTAssertTrue(CovJViewFixture.descendants(UILabel.self, in: cell).contains { $0.text == "Bound" })
        XCTAssertFalse(CovJViewFixture.descendants(UIImageView.self, in: cell).compactMap(\.image).isEmpty)
    }
}

final class CovJBkBackupSelectWalletRoutingTests: XCTestCase {
    func testCreatingANewWalletPushesTheNameScreen() throws {
        let host = try CovJHostedView()
        defer { host.close() }

        BackupSelectWalletRouter().showWalletNameScreen(from: host)

        XCTAssertTrue(host.top is WalletNameViewController)
    }

    func testChosenBackupOpensThePasswordScreenWhenItCanBeBuilt() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let service: KeystoreImportServiceProtocol? = URLHandlingService.shared.findService()

        BackupSelectWalletRouter().presentBackupPasswordScreen(
            for: [BackupAccount(account: OpenBackupAccount(address: "5Router"), current: true)],
            from: host
        )

        if service == nil {
            XCTAssertTrue(host.top === host.controller)
        } else {
            XCTAssertTrue(host.top is BackupPasswordViewController)
        }
    }

    func testAssemblyBuildsTheSelectionScreen() throws {
        let module = try XCTUnwrap(BackupSelectWalletAssembly.configureModule(accounts: [OpenBackupAccount(address: "5Assembly")]))

        XCTAssertTrue(module.view is BackupSelectWalletViewController)
        XCTAssertTrue(module.input is BackupSelectWalletPresenter)
    }
}
