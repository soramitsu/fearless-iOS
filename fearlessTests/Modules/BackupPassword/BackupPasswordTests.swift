import XCTest
import UIKit
import FearlessFoundation
import IrohaCrypto
import SSFCloudStorage
import SSFModels
@testable import fearless

final class BackupPasswordTests: XCTestCase {
    func testDidLoad_whenCurrentBackupExists_thenSetsUpInteractorAndProvidesWalletName() {
        let interactor = BackupPasswordInteractorInputSpy()
        let presenter = createPresenter(
            backupAccounts: [
                BackupAccount(account: makePasswordAccount(name: "Current", address: "current-address"), current: true)
            ],
            interactor: interactor
        )
        let view = BackupPasswordViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(view.walletName, "Current")
        XCTAssertNotNil(view.passwordInputViewModel)
    }

    func testDidLoad_whenCurrentBackupHasNoName_thenProvidesAddress() {
        let presenter = createPresenter(
            backupAccounts: [
                BackupAccount(account: makePasswordAccount(name: nil, address: "address-only"), current: true)
            ]
        )
        let view = BackupPasswordViewSpy()

        presenter.didLoad(view: view)

        XCTAssertEqual(view.walletName, "address-only")
    }

    func testDidContinueButtonTapped_whenPasswordEntered_thenStartsLoadingAndImportsBackup() {
        let interactor = BackupPasswordInteractorInputSpy()
        let currentAccount = makePasswordAccount(name: "Current", address: "current-address")
        let presenter = createPresenter(
            backupAccounts: [
                BackupAccount(account: currentAccount, current: true)
            ],
            interactor: interactor
        )
        let view = BackupPasswordViewSpy()

        presenter.didLoad(view: view)
        view.passwordInputViewModel?.inputHandler.changeValue(to: "secret")
        presenter.didContinueButtonTapped()

        XCTAssertEqual(view.didStartLoadingCallCount, 1)
        XCTAssertEqual(interactor.importedBackup?.address, "current-address")
        XCTAssertEqual(interactor.importedBackupPassword, "secret")
    }

    func testDidBackButtonTapped_whenViewLoaded_thenDismissesView() {
        let router = BackupPasswordRouterSpy()
        let presenter = createPresenter(router: router)
        let view = BackupPasswordViewSpy()

        presenter.didLoad(view: view)
        presenter.didBackButtonTapped()

        XCTAssertTrue(router.dismissedView === view)
    }

    func testDidReceiveBackup_whenSeedBackupSucceeds_thenImportsMetaAccount() {
        let interactor = BackupPasswordInteractorInputSpy()
        let presenter = createPresenter(interactor: interactor)
        let view = BackupPasswordViewSpy()
        let account = OpenBackupAccount(
            name: "Recovered",
            address: "recovered-address",
            cryptoType: CryptoType.sr25519.stringValue,
            substrateDerivationPath: "//hard",
            ethDerivationPath: "/44/60",
            backupAccountType: [.seed],
            encryptedSeed: OpenBackupAccount.Seed(substrateSeed: "substrate-seed", ethSeed: "eth-seed")
        )

        presenter.didLoad(view: view)
        presenter.didReceiveBackup(result: .success(account))

        XCTAssertEqual(view.didStopLoadingCallCount, 1)
        XCTAssertEqual(interactor.importRequest?.username, "Recovered")
        XCTAssertEqual(interactor.importRequest?.cryptoType, .sr25519)

        guard case let .seed(data)? = interactor.importRequest?.source else {
            return XCTFail("Expected seed import request")
        }

        XCTAssertEqual(data.substrateSeed, "substrate-seed")
        XCTAssertEqual(data.ethereumSeed, "eth-seed")
        XCTAssertEqual(data.substrateDerivationPath, "//hard")
        XCTAssertEqual(data.ethereumDerivationPath, "/44/60")
    }

    func testDidReceiveBackup_whenFailure_thenStopsLoadingAndPresentsError() {
        let router = BackupPasswordRouterSpy()
        let presenter = createPresenter(router: router)
        let view = BackupPasswordViewSpy()

        presenter.didLoad(view: view)
        presenter.didReceiveBackup(result: .failure(BackupPasswordTestError.failure))

        XCTAssertEqual(view.didStopLoadingCallCount, 1)
        XCTAssertNotNil(router.presentedError)
        XCTAssertTrue(router.errorView === view)
    }

    func testDidCompleteAccountImport_whenImportFinishes_thenShowsWalletImportedScreen() {
        let router = BackupPasswordRouterSpy()
        let backupAccounts = [
            BackupAccount(account: makePasswordAccount(name: "Current", address: "current-address"), current: true)
        ]
        let presenter = createPresenter(backupAccounts: backupAccounts, router: router)
        let view = BackupPasswordViewSpy()

        presenter.didLoad(view: view)
        presenter.didCompleteAccountImport()

        XCTAssertEqual(router.walletImportedAccounts.map { $0.account.address }, ["current-address"])
        XCTAssertTrue(router.walletImportedView === view)
    }

    func testDidReceiveAccountImportError_whenImportFails_thenPresentsError() {
        let router = BackupPasswordRouterSpy()
        let presenter = createPresenter(router: router)
        let view = BackupPasswordViewSpy()

        presenter.didLoad(view: view)
        presenter.didReceiveAccountImport(error: BackupPasswordTestError.failure)

        XCTAssertTrue(router.presentedError is BackupPasswordTestError)
        XCTAssertTrue(router.errorView === view)
    }

    func testConfigureModule_whenKeystoreImportServiceMissing_thenReturnsNilAndLogs() {
        let logger = LoggerSpy()
        let result = BackupPasswordAssembly.configureModule(
            backupAccounts: [],
            dependencies: BackupPasswordAssembly.Dependencies(
                keystoreImportServiceProvider: { nil },
                localizationManager: LocalizationManager.shared,
                logger: logger
            )
        )

        XCTAssertNil(result)
        XCTAssertEqual(logger.errorMessages, ["Missing required keystore import service"])
    }

    private func createPresenter(
        backupAccounts: [BackupAccount] = [
            BackupAccount(account: makePasswordAccount(name: "Wallet", address: "wallet-address"), current: true)
        ],
        interactor: BackupPasswordInteractorInput = BackupPasswordInteractorInputSpy(),
        router: BackupPasswordRouterInput = BackupPasswordRouterSpy(),
        logger: LoggerProtocol = LoggerSpy()
    ) -> BackupPasswordPresenter {
        BackupPasswordPresenter(
            backupAccounts: backupAccounts,
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            logger: logger
        )
    }
}

private final class BackupPasswordViewSpy: BackupPasswordViewInput {
    let controller = UIViewController()
    let isSetup = false
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true
    private(set) var walletName: String?
    private(set) var passwordInputViewModel: InputViewModelProtocol?
    private(set) var didStartLoadingCallCount = 0
    private(set) var didStopLoadingCallCount = 0

    func didReceive(walletName: String) {
        self.walletName = walletName
    }

    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol) {
        passwordInputViewModel = viewModel
    }

    func didStartLoading() {
        didStartLoadingCallCount += 1
    }

    func didStopLoading() {
        didStopLoadingCallCount += 1
    }
}

private final class BackupPasswordInteractorInputSpy: BackupPasswordInteractorInput {
    private(set) weak var output: BackupPasswordInteractorOutput?
    private(set) var importRequest: MetaAccountImportRequest?
    private(set) var importedBackup: OpenBackupAccount?
    private(set) var importedBackupPassword: String?
    private(set) var signInIfNeededCallCount = 0

    func setup(with output: BackupPasswordInteractorOutput) {
        self.output = output
    }

    func importBackup(account: OpenBackupAccount, password: String) {
        importedBackup = account
        importedBackupPassword = password
    }

    func signInIfNeeded() {
        signInIfNeededCallCount += 1
    }

    func setup() {}

    func importMetaAccount(request: MetaAccountImportRequest) {
        importRequest = request
    }

    func importUniqueChain(request _: UniqueChainImportRequest) {}

    func deriveMetadataFromKeystore(_: String) {}

    func createMnemonicFromString(_: String) -> IRMnemonicProtocol? {
        nil
    }
}

private final class BackupPasswordRouterSpy: BackupPasswordRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var errorView: ControllerBackedProtocol?
    private(set) weak var walletImportedView: ControllerBackedProtocol?
    private(set) var walletImportedAccounts: [BackupAccount] = []
    private(set) var presentedError: Error?
    private(set) var presentedTitle: String?
    private(set) var presentedActions: [SheetAlertPresentableAction] = []

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func showWalletImportedScreen(backupAccounts: [BackupAccount], from view: ControllerBackedProtocol?) {
        walletImportedAccounts = backupAccounts
        walletImportedView = view
    }

    func present(error: Error, from view: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        errorView = view
        return true
    }

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from view: ControllerBackedProtocol?
    ) {
        presentedTitle = viewModel.title
        presentedActions = viewModel.actions
        errorView = view
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
        errorView = view
    }

    func presentInfo(
        message _: String?,
        title: String,
        from view: ControllerBackedProtocol?
    ) {
        presentedTitle = title
        errorView = view
    }
}

private final class LoggerSpy: LoggerProtocol {
    private(set) var customErrors: [Error] = []
    private(set) var errorMessages: [String] = []

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message: String, file _: String, function _: String, line _: Int) {
        errorMessages.append(message)
    }

    func customError(error: Error, file _: String, function _: String, line _: Int) {
        customErrors.append(error)
    }
}

private enum BackupPasswordTestError: Error {
    case failure
}

private func makePasswordAccount(name: String?, address: String) -> OpenBackupAccount {
    OpenBackupAccount(name: name, address: address)
}
