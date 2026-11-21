import XCTest
import UIKit
import SoraFoundation
import SSFCloudStorage
@testable import fearless

final class CovJBkImportedView: BackupWalletImportedViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }
    private(set) var viewModels: [BackupWalletImportedViewModel] = []

    func didReceive(viewModel: BackupWalletImportedViewModel) { viewModels.append(viewModel) }
}

final class CovJBkImportedInteractor: BackupWalletImportedInteractorInput {
    var hasPin = true
    private(set) weak var output: BackupWalletImportedInteractorOutput?
    private(set) var disconnects = 0

    func setup(with output: BackupWalletImportedInteractorOutput) { self.output = output }
    func hasPincode() -> Bool { hasPin }
    func disconnect() { disconnects += 1 }
}

final class CovJBkImportedRouter: BackupWalletImportedRouterInput {
    private(set) var selections: [[OpenBackupAccount]] = []
    private(set) var pinSetups = 0
    private(set) var backs = 0
    private(set) var dismissals = 0

    func showBackupSelectWallet(for accounts: [OpenBackupAccount], from _: ControllerBackedProtocol?) {
        selections.append(accounts)
    }

    func showSetupPin() { pinSetups += 1 }
    func backButtonDidTapped(from _: ControllerBackedProtocol?) { backs += 1 }
    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
}

final class CovJBkImportedOutput: BackupWalletImportedViewOutput {
    private(set) var loads = 0
    private(set) var backs = 0
    private(set) var continues = 0
    private(set) var importMores = 0

    func didLoad(view _: BackupWalletImportedViewInput) { loads += 1 }
    func didBackButtonTapped() { backs += 1 }
    func didContinueButtonTapped() { continues += 1 }
    func didImportMoreButtonTapped() { importMores += 1 }
}

final class CovJBkImportedInteractorOutput: BackupWalletImportedInteractorOutput {}

/// A presenting controller that is also a module view, as the backup restore flow's presenter is.
final class CovJBkPresentingController: UIViewController, ControllerBackedProtocol {}

final class CovJBkBackupWalletImportedPresenterTests: XCTestCase {
    private struct Screen {
        let presenter: BackupWalletImportedPresenter
        let view: CovJBkImportedView
        let interactor: CovJBkImportedInteractor
        let router: CovJBkImportedRouter
    }

    private func makeScreen(_ accounts: [BackupAccount]) throws -> Screen {
        let view = CovJBkImportedView()
        let interactor = CovJBkImportedInteractor()
        let router = CovJBkImportedRouter()
        let presenter = BackupWalletImportedPresenter(
            backupAccounts: accounts,
            interactor: interactor,
            router: router,
            localizationManager: try CovJBkFixture.localization()
        )
        presenter.didLoad(view: view)
        return Screen(presenter: presenter, view: view, interactor: interactor, router: router)
    }

    func testImportedWalletIsNamedAndMoreBackupsCanBeImported() throws {
        let screen = try makeScreen([
            BackupAccount(account: OpenBackupAccount(name: "Imported", address: "5Imported"), current: true),
            BackupAccount(account: OpenBackupAccount(name: "Left", address: "5Left"), current: false)
        ])

        XCTAssertTrue(screen.interactor.output === screen.presenter)
        let viewModel = try XCTUnwrap(screen.view.viewModels.first)
        XCTAssertEqual(viewModel.walletName, "Imported")
        XCTAssertFalse(viewModel.importMoreButtomIsHidden)

        screen.presenter.didImportMoreButtonTapped()
        XCTAssertEqual(screen.router.selections.first?.map(\.address), ["5Left"])
    }

    func testLastBackupHidesImportMoreAndUnnamedBackupsShowTheirAddress() throws {
        let screen = try makeScreen([BackupAccount(account: OpenBackupAccount(address: "5Only"), current: true)])
        screen.presenter.applyLocalization()

        let viewModel = try XCTUnwrap(screen.view.viewModels.first)
        XCTAssertEqual(viewModel.walletName, "5Only")
        XCTAssertTrue(viewModel.importMoreButtomIsHidden)
    }

    func testNoCurrentBackupShowsNothing() throws {
        let screen = try makeScreen([BackupAccount(account: OpenBackupAccount(address: "5Other"), current: false)])

        XCTAssertTrue(screen.view.viewModels.isEmpty)
    }

    func testContinueSignsOutOfDriveAndEndsInTheAppOrPinSetup() throws {
        let withPin = try makeScreen([])
        withPin.presenter.didContinueButtonTapped()
        XCTAssertEqual(withPin.interactor.disconnects, 1)
        XCTAssertEqual(withPin.router.dismissals, 1)
        XCTAssertEqual(withPin.router.pinSetups, 0)

        let withoutPin = try makeScreen([])
        withoutPin.interactor.hasPin = false
        withoutPin.presenter.didContinueButtonTapped()
        withoutPin.presenter.didBackButtonTapped()
        XCTAssertEqual(withoutPin.interactor.disconnects, 1)
        XCTAssertEqual(withoutPin.router.pinSetups, 1)
        XCTAssertEqual(withoutPin.router.dismissals, 0)
        XCTAssertEqual(withoutPin.router.backs, 1)
    }
}

final class CovJBkBackupWalletImportedComponentTests: XCTestCase {
    private var languages: [String]? { CovJBkFixture.languages }

    func testInteractorChecksThePinAndDisconnectsDrive() {
        let secrets = CovJBkSecretManager()
        let interactor = BackupWalletImportedInteractor(secretManager: secrets)
        let cloud = CovJBkCloudStorage()
        let output = CovJBkImportedInteractorOutput()
        interactor.setup(with: output)

        XCTAssertFalse(interactor.hasPincode())
        secrets.hasSecret = true
        XCTAssertTrue(interactor.hasPincode())
        XCTAssertEqual(secrets.checked, [fearless.KeystoreTag.pincode.rawValue, fearless.KeystoreTag.pincode.rawValue])

        interactor.disconnect()
        interactor.cloudStorageService = cloud
        interactor.disconnect()
        XCTAssertEqual(cloud.calls, ["disconnect"])
    }

    func testControllerShowsTheWalletAndForwardsItsButtons() throws {
        let output = CovJBkImportedOutput()
        let controller = BackupWalletImportedViewController(output: output, localizationManager: try CovJBkFixture.localization())
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = controller.rootView

        controller.didReceive(viewModel: BackupWalletImportedViewModel(walletName: "Shown", importMoreButtomIsHidden: true))
        controller.applyLocalization()
        XCTAssertEqual(root.walletNameLabel.text, "Shown")
        XCTAssertTrue(root.importMoreButton.isHidden)
        XCTAssertEqual(
            root.navigationBar.titleLabel.text,
            R.string.localizable.backupWalletImportedTitle(preferredLanguages: languages)
        )

        controller.didReceive(viewModel: BackupWalletImportedViewModel(walletName: "Again", importMoreButtomIsHidden: false))
        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        root.continueButton.sendActions(for: .touchUpInside)
        root.importMoreButton.sendActions(for: .touchUpInside)

        XCTAssertFalse(root.importMoreButton.isHidden)
        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(output.backs, 1)
        XCTAssertEqual(output.continues, 1)
        XCTAssertEqual(output.importMores, 1)
    }

    func testAssemblyBuildsTheImportedScreen() throws {
        let module = try XCTUnwrap(BackupWalletImportedAssembly.configureModule(backupAccounts: [
            BackupAccount(account: OpenBackupAccount(address: "5Assembly"), current: true)
        ]))

        XCTAssertTrue(module.view is BackupWalletImportedViewController)
        XCTAssertTrue(module.input is BackupWalletImportedPresenter)
    }
}

final class CovJBkBackupWalletImportedRoutingTests: XCTestCase {
    func testPinSetupReplacesTheRootThroughTheAnimator() {
        let router = BackupWalletImportedRouter()
        let animator = CovJBkRootAnimator()
        router.rootAnimator = animator

        router.showSetupPin()

        XCTAssertEqual(animator.controllers.count, 1)
        XCTAssertNotNil(animator.controllers.first as? PinSetupViewProtocol)
    }

    func testBackClosesTheRestoreModal() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let restored = UIViewController()
        host.controller.present(UINavigationController(rootViewController: restored), animated: false)
        XCTAssertNotNil(host.presented)

        BackupWalletImportedRouter().backButtonDidTapped(from: CovJBkControllerView(restored))

        XCTAssertTrue(CovJWait.until { host.presented == nil })
    }

    func testImportMoreReopensTheSelectionFromThePresentingScreen() throws {
        let presenting = CovJBkPresentingController()
        let window = try CovJViewFixture.host(presenting)
        defer { window.isHidden = true }
        let restored = UIViewController()
        presenting.present(UINavigationController(rootViewController: restored), animated: false)
        XCTAssertNotNil(presenting.presentedViewController)

        BackupWalletImportedRouter().showBackupSelectWallet(
            for: [OpenBackupAccount(name: "Next", address: "5Next")],
            from: CovJBkControllerView(restored)
        )

        XCTAssertTrue(CovJWait.until(timeout: 3) {
            (presenting.presentedViewController as? FearlessNavigationController)?.viewControllers.first
                is BackupSelectWalletViewController
        })
        let selection = try XCTUnwrap(
            (presenting.presentedViewController as? UINavigationController)?.viewControllers.first as? BackupSelectWalletViewController
        )
        XCTAssertTrue(CovJWait.until { selection.viewModels == ["Next"] })
    }
}
