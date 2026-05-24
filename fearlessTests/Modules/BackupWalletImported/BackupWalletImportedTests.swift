import XCTest
import UIKit
import FearlessFoundation
import SSFCloudStorage
@testable import fearless

final class BackupWalletImportedTests: XCTestCase {
    func testDidLoad_whenCurrentAccountExists_thenSetsUpInteractorAndProvidesViewModel() {
        let interactor = BackupWalletImportedInteractorInputSpy()
        let presenter = createPresenter(
            backupAccounts: [
                BackupAccount(account: makeImportedAccount(name: "Imported", address: "imported-address"), current: true),
                BackupAccount(account: makeImportedAccount(name: "Other", address: "other-address"), current: false)
            ],
            interactor: interactor
        )
        let view = BackupWalletImportedViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(view.viewModel?.walletName, "Imported")
        XCTAssertEqual(view.viewModel?.importMoreButtomIsHidden, false)
    }

    func testDidLoad_whenOnlyCurrentAccountExists_thenHidesImportMoreButton() {
        let presenter = createPresenter(
            backupAccounts: [
                BackupAccount(account: makeImportedAccount(name: nil, address: "address-only"), current: true)
            ]
        )
        let view = BackupWalletImportedViewSpy()

        presenter.didLoad(view: view)

        XCTAssertEqual(view.viewModel?.walletName, "address-only")
        XCTAssertEqual(view.viewModel?.importMoreButtomIsHidden, true)
    }

    func testDidContinueButtonTapped_whenPincodeExists_thenDisconnectsAndDismisses() {
        let interactor = BackupWalletImportedInteractorInputSpy(hasPincode: true)
        let router = BackupWalletImportedRouterSpy()
        let presenter = createPresenter(interactor: interactor, router: router)
        let view = BackupWalletImportedViewSpy()

        presenter.didLoad(view: view)
        presenter.didContinueButtonTapped()

        XCTAssertEqual(interactor.disconnectCallCount, 1)
        XCTAssertTrue(router.dismissedView === view)
        XCTAssertEqual(router.showSetupPinCallCount, 0)
    }

    func testDidContinueButtonTapped_whenPincodeMissing_thenShowsPinSetup() {
        let interactor = BackupWalletImportedInteractorInputSpy(hasPincode: false)
        let router = BackupWalletImportedRouterSpy()
        let presenter = createPresenter(interactor: interactor, router: router)
        let view = BackupWalletImportedViewSpy()

        presenter.didLoad(view: view)
        presenter.didContinueButtonTapped()

        XCTAssertEqual(interactor.disconnectCallCount, 1)
        XCTAssertNil(router.dismissedView)
        XCTAssertEqual(router.showSetupPinCallCount, 1)
    }

    func testDidImportMoreButtonTapped_whenAdditionalAccountsExist_thenRoutesWithNonCurrentAccounts() {
        let router = BackupWalletImportedRouterSpy()
        let presenter = createPresenter(
            backupAccounts: [
                BackupAccount(account: makeImportedAccount(name: "Current", address: "current-address"), current: true),
                BackupAccount(account: makeImportedAccount(name: "Other", address: "other-address"), current: false)
            ],
            router: router
        )
        let view = BackupWalletImportedViewSpy()

        presenter.didLoad(view: view)
        presenter.didImportMoreButtonTapped()

        XCTAssertEqual(router.backupSelectAccounts.map(\.address), ["other-address"])
        XCTAssertTrue(router.backupSelectView === view)
    }

    func testDidBackButtonTapped_whenViewLoaded_thenRoutesBack() {
        let router = BackupWalletImportedRouterSpy()
        let presenter = createPresenter(router: router)
        let view = BackupWalletImportedViewSpy()

        presenter.didLoad(view: view)
        presenter.didBackButtonTapped()

        XCTAssertTrue(router.backButtonView === view)
    }

    private func createPresenter(
        backupAccounts: [BackupAccount] = [
            BackupAccount(account: makeImportedAccount(name: "Wallet", address: "wallet-address"), current: true)
        ],
        interactor: BackupWalletImportedInteractorInput = BackupWalletImportedInteractorInputSpy(),
        router: BackupWalletImportedRouterInput = BackupWalletImportedRouterSpy()
    ) -> BackupWalletImportedPresenter {
        BackupWalletImportedPresenter(
            backupAccounts: backupAccounts,
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared
        )
    }
}

private final class BackupWalletImportedViewSpy: BackupWalletImportedViewInput {
    let controller = UIViewController()
    let isSetup = false
    private(set) var viewModel: BackupWalletImportedViewModel?

    func didReceive(viewModel: BackupWalletImportedViewModel) {
        self.viewModel = viewModel
    }
}

private final class BackupWalletImportedInteractorInputSpy: BackupWalletImportedInteractorInput {
    private(set) weak var output: BackupWalletImportedInteractorOutput?
    private(set) var disconnectCallCount = 0
    private let pincodeExists: Bool

    init(hasPincode: Bool = true) {
        pincodeExists = hasPincode
    }

    func setup(with output: BackupWalletImportedInteractorOutput) {
        self.output = output
    }

    func hasPincode() -> Bool {
        pincodeExists
    }

    func disconnect() {
        disconnectCallCount += 1
    }
}

private final class BackupWalletImportedRouterSpy: BackupWalletImportedRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var backupSelectView: ControllerBackedProtocol?
    private(set) weak var backButtonView: ControllerBackedProtocol?
    private(set) var backupSelectAccounts: [OpenBackupAccount] = []
    private(set) var showSetupPinCallCount = 0

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func showBackupSelectWallet(
        for accounts: [OpenBackupAccount],
        from view: ControllerBackedProtocol?
    ) {
        backupSelectAccounts = accounts
        backupSelectView = view
    }

    func showSetupPin() {
        showSetupPinCallCount += 1
    }

    func backButtonDidTapped(from view: ControllerBackedProtocol?) {
        backButtonView = view
    }
}

private func makeImportedAccount(name: String?, address: String) -> OpenBackupAccount {
    OpenBackupAccount(name: name, address: address)
}
