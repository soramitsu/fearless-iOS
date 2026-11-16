import XCTest
import UIKit
import SoraFoundation
import SSFCloudStorage
import SSFModels
@testable import fearless

final class CovJBkBackupWalletView: CovJBkLoadableView, BackupWalletViewInput {
    private(set) var viewModels: [ProfileViewModelProtocol] = []

    func didReceive(viewModel: ProfileViewModelProtocol) {
        viewModels.append(viewModel)
    }
}

final class CovJBkBackupWalletInteractor: BackupWalletInteractorInput {
    private(set) weak var output: BackupWalletInteractorOutput?
    private(set) var setups = 0
    private(set) var removals = 0
    private(set) var appearances = 0

    func setup(with output: BackupWalletInteractorOutput) {
        self.output = output
        setups += 1
    }

    func removeBackupFromGoogle() { removals += 1 }
    func viewDidAppear() { appearances += 1 }
}

final class CovJBkBackupWalletFactory: BackupWalletViewModelFactoryProtocol {
    struct Call {
        let balance: WalletBalanceInfo?
        let exportOptions: [ExportOption]
        let backupAccounts: [OpenBackupAccount]?
    }

    private(set) var calls: [Call] = []

    func createViewModel(
        from wallet: MetaAccountModel,
        locale _: Locale,
        balance: WalletBalanceInfo?,
        exportOptions: [ExportOption],
        backupAccounts: [OpenBackupAccount]?
    ) -> ProfileViewModelProtocol {
        calls.append(Call(balance: balance, exportOptions: exportOptions, backupAccounts: backupAccounts))
        return CovJBkFixture.profileViewModel(name: wallet.name, options: exportOptions.map { "\($0)" })
    }
}

final class CovJBkBackupWalletRouter: BackupWalletRouterInput {
    private(set) var exports: [String] = []
    private(set) var flows: [ExportFlow] = []
    private(set) var passwordSteps: [(wallet: MetaAccountModel, options: [ExportOption], output: BackupCreatePasswordModuleOutput?)] = []
    private(set) var walletDetails: [MetaAccountModel] = []
    private(set) var sheets: [SheetAlertPresentableViewModel] = []
    private(set) var messages: [(title: String, message: String?, closeAction: String?)] = []
    private(set) var errors: [Error] = []
    private(set) var notifications: [String] = []
    private(set) var dismissals = 0

    func showMnemonicExport(flow: ExportFlow, from _: ControllerBackedProtocol?) {
        exports.append("mnemonic")
        flows.append(flow)
    }

    func showKeystoreExport(flow: ExportFlow, from _: ControllerBackedProtocol?) {
        exports.append("keystore")
        flows.append(flow)
    }

    func showSeedExport(flow: ExportFlow, from _: ControllerBackedProtocol?) {
        exports.append("seed")
        flows.append(flow)
    }

    func showCreatePassword(
        wallet: MetaAccountModel,
        accounts _: [ChainAccountInfo],
        options: [ExportOption],
        from _: ControllerBackedProtocol?,
        moduleOutput: BackupCreatePasswordModuleOutput?
    ) {
        passwordSteps.append((wallet, options, moduleOutput))
    }

    func showWalletDetails(wallet: MetaAccountModel, from _: ControllerBackedProtocol?) {
        walletDetails.append(wallet)
    }

    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheets.append(viewModel)
    }

    func present(
        message: String?,
        title: String,
        closeAction: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        messages.append((title, message, closeAction))
    }

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return true
    }

    func presentSuccessNotification(_ title: String, from _: ControllerBackedProtocol?, completion _: (() -> Void)?) {
        notifications.append(title)
    }
}

final class CovJBkBackupWalletPresenterTests: XCTestCase {
    private var languages: [String]? { CovJBkFixture.languages }

    private struct Screen {
        let presenter: BackupWalletPresenter
        let view: CovJBkBackupWalletView
        let interactor: CovJBkBackupWalletInteractor
        let router: CovJBkBackupWalletRouter
        let factory: CovJBkBackupWalletFactory
    }

    private func makeScreen(wallet: MetaAccountModel) throws -> Screen {
        let view = CovJBkBackupWalletView()
        let interactor = CovJBkBackupWalletInteractor()
        let router = CovJBkBackupWalletRouter()
        let factory = CovJBkBackupWalletFactory()
        let presenter = BackupWalletPresenter(
            wallet: wallet,
            interactor: interactor,
            router: router,
            logger: Logger.shared,
            localizationManager: try CovJBkFixture.localization(),
            viewModelFactory: factory
        )
        presenter.didLoad(view: view)
        return Screen(presenter: presenter, view: view, interactor: interactor, router: router, factory: factory)
    }

    func testLoadingSetsUpTheInteractorAndShowsTheBuiltViewModel() throws {
        let wallet = CovJBkFixture.wallet(name: "Main")
        let screen = try makeScreen(wallet: wallet)

        XCTAssertEqual(screen.interactor.setups, 1)
        XCTAssertTrue(screen.interactor.output === screen.presenter)
        XCTAssertEqual(screen.factory.calls.count, 1)
        XCTAssertNil(screen.factory.calls.first?.balance)
        XCTAssertNil(screen.factory.calls.first?.backupAccounts)
        XCTAssertTrue(CovJWait.until { screen.view.viewModels.count == 1 })
        XCTAssertEqual(screen.view.viewModels.first?.profileUserViewModel.walletName, "Main")
        screen.presenter.applyLocalization()
        XCTAssertTrue(screen.router.sheets.isEmpty)
    }

    func testOptionsAndBalancesRebuildTheViewModelWhileFailuresOnlyLog() throws {
        let wallet = CovJBkFixture.wallet()
        let screen = try makeScreen(wallet: wallet)

        screen.presenter.didReceive(options: [.mnemonic, .keystore])
        XCTAssertEqual(screen.factory.calls.last?.exportOptions, [.mnemonic, .keystore])

        screen.presenter.didReceiveBalances(result: .success([wallet.metaId: CovJBkFixture.balance(for: wallet, total: 77)]))
        XCTAssertEqual(screen.factory.calls.count, 3)
        XCTAssertEqual(screen.factory.calls.last?.balance?.totalFiatValue, 77)

        screen.presenter.didReceiveBalances(result: .failure(CovJError("balances")))
        screen.presenter.didReceive(error: CovJError("chains"))
        XCTAssertEqual(screen.factory.calls.count, 3)
        XCTAssertTrue(screen.router.errors.isEmpty)
        XCTAssertTrue(CovJWait.until { screen.view.viewModels.count == 3 })
    }

    func testExportRowsOpenTheirExportsWithTheWalletsOwnAccounts() throws {
        let polkadot = CovJFixture.chain(id: "covjbk-polkadot", name: "Polkadot", addressPrefix: 0)
        let kusama = CovJFixture.chain(id: "covjbk-kusama", name: "Kusama", addressPrefix: 2)
        let wallet = CovJBkFixture.wallet(chainAccounts: [CovJBkFixture.chainAccount(chainId: kusama.chainId, seed: 9)])
        let screen = try makeScreen(wallet: wallet)
        screen.presenter.didReceive(chains: [polkadot, kusama])
        screen.presenter.didReceive(options: [.mnemonic, .seed, .keystore])

        screen.presenter.didSelectRowAt(IndexPath(row: 0, section: 0))
        XCTAssertTrue(screen.router.exports.isEmpty)

        for row in 0 ..< 3 {
            screen.presenter.didSelectRowAt(IndexPath(row: row, section: 1))
        }

        XCTAssertEqual(screen.router.exports, ["mnemonic", "seed", "keystore"])
        guard case let .multiple(exportedWallet, accounts) = try XCTUnwrap(screen.router.flows.first) else {
            return XCTFail("The backup screen exports the whole wallet")
        }
        XCTAssertEqual(exportedWallet.metaId, wallet.metaId)
        XCTAssertEqual(accounts.map(\.chain.chainId), [polkadot.chainId], "The per-network Kusama account is left out")
        XCTAssertEqual(accounts.first?.account.accountId, wallet.substrateAccountId)
    }

    func testGoogleRowAsksBeforeRemovingTheBackupDriveHolds() throws {
        let wallet = CovJBkFixture.wallet()
        let screen = try makeScreen(wallet: wallet)
        screen.presenter.didReceiveBackupAccounts(result: .success([OpenBackupAccount(address: wallet.backupAddress)]))
        XCTAssertEqual(screen.view.stops, 1)
        XCTAssertEqual(screen.factory.calls.last?.backupAccounts?.count, 1)

        screen.presenter.didSelectRowAt(IndexPath(row: 0, section: 1))

        let sheet = try XCTUnwrap(screen.router.sheets.last)
        XCTAssertEqual(sheet.title, R.string.localizable.commonConfirmTitle(preferredLanguages: languages))
        XCTAssertEqual(sheet.message, R.string.localizable.backupWalletDeleteMessage(preferredLanguages: languages))
        XCTAssertEqual(sheet.actions.map(\.title), [
            R.string.localizable.commonCancel(preferredLanguages: languages),
            R.string.localizable.connectionDeleteConfirm(preferredLanguages: languages)
        ])
        XCTAssertNil(sheet.closeAction)
        XCTAssertEqual(sheet.actionAxis, .horizontal)
        XCTAssertNil(sheet.actions.first?.handler)
        XCTAssertEqual(screen.interactor.removals, 0)

        sheet.actions.last?.handler?()
        XCTAssertEqual(screen.view.starts, 1)
        XCTAssertEqual(screen.interactor.removals, 1)
    }

    func testRemovedBackupIsAnnouncedAndDroppedFromTheList() throws {
        let wallet = CovJBkFixture.wallet()
        let screen = try makeScreen(wallet: wallet)
        let other = OpenBackupAccount(address: "5CovJBkOtherAddress")
        screen.presenter.didReceiveBackupAccounts(result: .success([OpenBackupAccount(address: wallet.backupAddress), other]))

        screen.presenter.didReceiveRemove(result: .success(()))

        XCTAssertEqual(screen.view.stops, 2)
        XCTAssertEqual(screen.router.notifications, [R.string.localizable.commonDone(preferredLanguages: languages)])
        XCTAssertEqual(screen.factory.calls.last?.backupAccounts?.map(\.address), [other.address])
    }

    func testRemovalFailuresExplainWhatHappened() throws {
        let screen = try makeScreen(wallet: CovJBkFixture.wallet())

        screen.presenter.didReceiveRemove(result: .failure(FearlessExtensionError.cantRemoveExtensionBackup))
        let message = try XCTUnwrap(screen.router.messages.last)
        XCTAssertEqual(message.title, R.string.localizable.commonWarning(preferredLanguages: languages))
        XCTAssertEqual(message.message, R.string.localizable.removeBackupExtensionErrorMessage(preferredLanguages: languages))
        XCTAssertEqual(message.closeAction, R.string.localizable.commonClose(preferredLanguages: languages))
        XCTAssertTrue(screen.router.errors.isEmpty)

        screen.presenter.didReceiveRemove(result: .failure(FearlessExtensionError.backupNotFound))
        XCTAssertEqual((screen.router.errors.last as? ConvenienceError)?.error, "Backup is not found")

        let generic = CovJError("drive")
        screen.presenter.didReceiveRemove(result: .failure(generic))
        XCTAssertEqual((screen.router.errors.last as? ConvenienceError)?.error, generic.localizedDescription)
        XCTAssertEqual(screen.router.errors.count, 2)
        XCTAssertEqual(screen.view.stops, 3)
    }

    func testDriveFailureOffersARetryUntilTheSheetCloses() throws {
        let screen = try makeScreen(wallet: CovJBkFixture.wallet())

        screen.presenter.didReceiveBackupAccounts(result: .failure(CovJError("offline")))

        XCTAssertNil(screen.factory.calls.last?.backupAccounts)
        let sheet = try XCTUnwrap(screen.router.sheets.last)
        XCTAssertEqual(sheet.title, R.string.localizable.noAccessToGoogle(preferredLanguages: languages))
        XCTAssertNil(sheet.message)
        XCTAssertEqual(sheet.actions.map(\.title), [R.string.localizable.tryAgain(preferredLanguages: languages)])
        sheet.actions.first?.handler?()
        XCTAssertEqual(screen.interactor.appearances, 1)

        screen.presenter.viewDidAppear()
        XCTAssertEqual(screen.view.starts, 1)
        XCTAssertEqual(screen.interactor.appearances, 2)

        sheet.dismissCompletion?()
        screen.presenter.viewDidAppear()
        XCTAssertEqual(screen.interactor.appearances, 2, "Closing the sheet stops asking Google again")
    }

    func testCompletedBackupIsAnnouncedOnceWhenTheScreenReturns() throws {
        let screen = try makeScreen(wallet: CovJBkFixture.wallet())

        screen.presenter.backupDidComplete()
        XCTAssertEqual(screen.interactor.appearances, 1)

        screen.presenter.viewDidAppear()
        XCTAssertEqual(screen.router.notifications, [R.string.localizable.backupWalletBackupGoogle(preferredLanguages: languages)])
        XCTAssertEqual(screen.interactor.appearances, 2)

        screen.presenter.viewDidAppear()
        XCTAssertEqual(screen.router.notifications.count, 1)
        XCTAssertEqual(screen.interactor.appearances, 3)

        screen.presenter.didReceiveBackupAccounts(result: .success([]))
        screen.presenter.viewDidAppear()
        XCTAssertEqual(screen.interactor.appearances, 3, "An authorized Google account is not asked again")
        XCTAssertEqual(screen.factory.calls.last?.backupAccounts?.count, 0)
    }

    func testOneReplacedAccountIsNamedAndCanOpenWalletDetails() throws {
        let kusama = CovJFixture.chain(id: "covjbk-kusama-single", name: "Kusama", addressPrefix: 2)
        let account = CovJBkFixture.chainAccount(chainId: kusama.chainId, seed: 9)
        let wallet = CovJBkFixture.wallet(chainAccounts: [account])
        let screen = try makeScreen(wallet: wallet)
        screen.presenter.didReceive(chains: [kusama])

        screen.presenter.viewDidAppear()

        let address = try account.accountId.toAddress(using: .substrate(2))
        let sheet = try XCTUnwrap(screen.router.sheets.last)
        XCTAssertEqual(sheet.title, R.string.localizable.commonWarning(preferredLanguages: languages))
        XCTAssertEqual(
            sheet.message,
            R.string.localizable.backupWalletReplaceAccountsAlert("Kusama", address, preferredLanguages: languages)
        )
        XCTAssertEqual(sheet.actions.map(\.title), [R.string.localizable.backupChainAccount(preferredLanguages: languages)])
        XCTAssertEqual(screen.interactor.appearances, 0)

        sheet.actions.first?.handler?()
        XCTAssertEqual(screen.router.walletDetails.map(\.metaId), [wallet.metaId])
        sheet.dismissCompletion?()
        XCTAssertEqual(screen.interactor.appearances, 0, "Wallet details opened instead")

        screen.presenter.viewDidAppear()
        XCTAssertEqual(screen.router.sheets.count, 1, "The warning is shown once")
        XCTAssertEqual(screen.interactor.appearances, 1)
    }

    func testSeveralReplacedAccountsShareOneWarningAndTheScreenContinuesWhenClosed() throws {
        let wallet = CovJBkFixture.wallet(chainAccounts: [
            CovJBkFixture.chainAccount(chainId: "covjbk-a", seed: 3),
            CovJBkFixture.chainAccount(chainId: "covjbk-b", seed: 4)
        ])
        let screen = try makeScreen(wallet: wallet)

        screen.presenter.viewDidAppear()

        let sheet = try XCTUnwrap(screen.router.sheets.last)
        XCTAssertEqual(sheet.message, R.string.localizable.backupWalletReplaceSeveralAlert(preferredLanguages: languages))
        sheet.dismissCompletion?()
        XCTAssertEqual(screen.interactor.appearances, 1)
        XCTAssertEqual(screen.view.starts, 1)
        XCTAssertTrue(screen.router.walletDetails.isEmpty)
    }

    func testWalletWithoutSubstrateKeyExplainsGoogleAndOffersTheOtherExports() throws {
        let screen = try makeScreen(wallet: CovJBkFixture.wallet(substrate: false))
        screen.presenter.didReceive(options: [.seed, .keystore])

        screen.presenter.didSelectRowAt(IndexPath(row: 2, section: 1))

        XCTAssertTrue(screen.router.passwordSteps.isEmpty)
        let sheet = try XCTUnwrap(screen.router.sheets.last)
        XCTAssertEqual(sheet.title, R.string.localizable.backupGoogleNotCreatedTitle(preferredLanguages: languages))
        XCTAssertEqual(sheet.message, R.string.localizable.backupGoogleSubstrateUnsupportedMessage(preferredLanguages: languages))
        XCTAssertEqual(sheet.actions.map(\.title), [
            R.string.localizable.backupWalletSeed(preferredLanguages: languages),
            R.string.localizable.backupWalletJson(preferredLanguages: languages)
        ])
        XCTAssertEqual(sheet.closeAction, R.string.localizable.commonClose(preferredLanguages: languages))

        sheet.dismissCompletion?()
        XCTAssertTrue(screen.router.exports.isEmpty, "Closing without a choice opens nothing")

        sheet.actions.last?.handler?()
        sheet.dismissCompletion?()
        XCTAssertEqual(screen.router.exports, ["keystore"])
    }

    func testGoogleRowOpensThePasswordStepWhenDriveHasNoBackupOfTheWallet() throws {
        let wallet = CovJBkFixture.wallet()
        let screen = try makeScreen(wallet: wallet)
        screen.presenter.didReceive(options: [.keystore])
        screen.presenter.didReceiveBackupAccounts(result: .success([]))

        screen.presenter.didSelectRowAt(IndexPath(row: 1, section: 1))

        let step = try XCTUnwrap(screen.router.passwordSteps.last)
        XCTAssertEqual(step.wallet.metaId, wallet.metaId)
        XCTAssertEqual(step.options, [.keystore])
        XCTAssertTrue(step.output === screen.presenter)
        XCTAssertTrue(screen.router.sheets.isEmpty)
    }

    func testBackButtonDismissesTheScreen() throws {
        let screen = try makeScreen(wallet: CovJBkFixture.wallet())

        screen.presenter.backButtonDidTapped()

        XCTAssertEqual(screen.router.dismissals, 1)
    }
}
