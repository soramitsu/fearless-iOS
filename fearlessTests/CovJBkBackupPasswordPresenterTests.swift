import XCTest
import UIKit
import IrohaCrypto
import SoraFoundation
import SSFCloudStorage
import SSFModels
@testable import fearless

final class CovJBkBackupPasswordView: CovJBkLoadableView, BackupPasswordViewInput {
    private(set) var names: [String] = []
    private(set) var passwordViewModel: InputViewModelProtocol?

    func didReceive(walletName: String) { names.append(walletName) }
    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol) { passwordViewModel = viewModel }
}

final class CovJBkBackupPasswordInteractor: BackupPasswordInteractorInput {
    private(set) weak var output: BackupPasswordInteractorOutput?
    private(set) var requests: [MetaAccountImportRequest] = []
    private(set) var backupImports: [(address: String, password: String)] = []
    private(set) var signIns = 0

    func setup() {}
    func importMetaAccount(request: MetaAccountImportRequest) { requests.append(request) }
    func importUniqueChain(request _: UniqueChainImportRequest) {}
    func deriveMetadataFromKeystore(_: String) {}

    func createMnemonicFromString(_ mnemonicString: String) -> IRMnemonicProtocol? {
        try? IRMnemonicCreator().mnemonic(fromList: mnemonicString)
    }

    func setup(with output: BackupPasswordInteractorOutput) { self.output = output }

    func importBackup(account: OpenBackupAccount, password: String) {
        backupImports.append((account.address, password))
    }

    func signInIfNeeded() { signIns += 1 }
}

final class CovJBkBackupPasswordRouter: BackupPasswordRouterInput {
    private(set) var importedScreens: [[BackupAccount]] = []
    private(set) var messages: [(title: String, message: String?, actions: [SheetAlertPresentableAction])] = []
    private(set) var errors: [Error] = []
    private(set) var dismissals = 0

    func showWalletImportedScreen(backupAccounts: [BackupAccount], from _: ControllerBackedProtocol?) {
        importedScreens.append(backupAccounts)
    }

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

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return true
    }
}

final class CovJBkBackupPasswordPresenterTests: XCTestCase {
    private var languages: [String]? { CovJBkFixture.languages }

    private struct Screen {
        let presenter: BackupPasswordPresenter
        let view: CovJBkBackupPasswordView
        let interactor: CovJBkBackupPasswordInteractor
        let router: CovJBkBackupPasswordRouter
    }

    private func makeScreen(_ accounts: [BackupAccount], password: String? = nil) throws -> Screen {
        let view = CovJBkBackupPasswordView()
        let interactor = CovJBkBackupPasswordInteractor()
        let router = CovJBkBackupPasswordRouter()
        let presenter = BackupPasswordPresenter(
            backupAccounts: accounts,
            interactor: interactor,
            router: router,
            localizationManager: try CovJBkFixture.localization(),
            logger: Logger.shared
        )
        presenter.didLoad(view: view)
        if let password {
            try XCTUnwrap(view.passwordViewModel).inputHandler.changeValue(to: password)
        }
        return Screen(presenter: presenter, view: view, interactor: interactor, router: router)
    }

    private func restore(_ backup: OpenBackupAccount, password: String? = nil) throws -> Screen {
        let screen = try makeScreen([BackupAccount(account: backup, current: true)], password: password)
        screen.presenter.didReceiveBackup(result: .success(backup))
        return screen
    }

    private func assertCommonError(_ screen: Screen, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(screen.interactor.requests.isEmpty, file: file, line: line)
        XCTAssertEqual(screen.router.messages.count, 1, file: file, line: line)
        XCTAssertEqual(
            screen.router.messages.first?.title,
            R.string.localizable.commonUndefinedErrorTitle(preferredLanguages: languages),
            file: file, line: line
        )
        XCTAssertEqual(
            screen.router.messages.first?.message,
            R.string.localizable.commonUndefinedErrorMessage(preferredLanguages: languages),
            file: file, line: line
        )
    }

    func testLoadShowsTheChosenBackupByNameOrAddress() throws {
        let named = try makeScreen([
            BackupAccount(account: OpenBackupAccount(name: "Other", address: "5Other"), current: false),
            BackupAccount(account: OpenBackupAccount(name: "Travel", address: "5Travel"), current: true)
        ])
        XCTAssertEqual(named.view.names, ["Travel"])
        XCTAssertTrue(named.interactor.output === named.presenter)
        XCTAssertNotNil(named.view.passwordViewModel)

        let unnamed = try makeScreen([BackupAccount(account: OpenBackupAccount(address: "5Unnamed"), current: true)])
        XCTAssertEqual(unnamed.view.names, ["5Unnamed"])

        let unchosen = try makeScreen([BackupAccount(account: OpenBackupAccount(address: "5None"), current: false)])
        XCTAssertTrue(unchosen.view.names.isEmpty)
        unchosen.presenter.didContinueButtonTapped()
        XCTAssertEqual(unchosen.view.starts, 1)
        XCTAssertTrue(unchosen.interactor.backupImports.isEmpty)
    }

    func testContinueDownloadsTheChosenBackupWithTheTypedPasswordAndBackDismisses() throws {
        let screen = try makeScreen([BackupAccount(account: OpenBackupAccount(name: "Main", address: "5Main"), current: true)], password: "s3cret")

        screen.presenter.didContinueButtonTapped()
        screen.presenter.didBackButtonTapped()
        screen.presenter.applyLocalization()

        XCTAssertEqual(screen.view.starts, 1)
        XCTAssertEqual(screen.interactor.backupImports.map(\.address), ["5Main"])
        XCTAssertEqual(screen.interactor.backupImports.map(\.password), ["s3cret"])
        XCTAssertEqual(screen.router.dismissals, 1)
    }

    func testGoogleProblemOffersToSignInAgain() throws {
        let screen = try makeScreen([])

        screen.presenter.showGoogleIssueError()

        let message = try XCTUnwrap(screen.router.messages.last)
        XCTAssertEqual(message.title, R.string.localizable.noAccessToGoogle(preferredLanguages: languages))
        XCTAssertNil(message.message)
        XCTAssertEqual(message.actions.map(\.title), [R.string.localizable.tryAgain(preferredLanguages: languages)])
        message.actions.first?.handler?()
        XCTAssertEqual(screen.interactor.signIns, 1)
    }

    func testImportOutcomesAndDriveFailuresAreRouted() throws {
        let accounts = [
            BackupAccount(account: OpenBackupAccount(address: "5A"), current: true),
            BackupAccount(account: OpenBackupAccount(address: "5B"), current: false)
        ]
        let screen = try makeScreen(accounts)

        screen.presenter.didReceiveAccountImport(error: CovJError("import"))
        screen.presenter.didCompleteAccountImport()
        screen.presenter.didReceiveBackup(result: .failure(CloudStorageServiceError.incorectPassword))

        XCTAssertEqual(screen.router.errors.first as? CovJError, CovJError("import"))
        XCTAssertEqual(screen.router.importedScreens.first?.map(\.account.address), ["5A", "5B"])
        XCTAssertEqual(screen.router.importedScreens.first?.map(\.current), [true, false])
        XCTAssertEqual((screen.router.errors.last as? ConvenienceError)?.error, "Incorect password")
        XCTAssertEqual(screen.view.stops, 1)
    }

    func testPhraseBackupImportsItsWordsAndPaths() throws {
        let backup = OpenBackupAccount(
            name: "Phrase", address: "5Phrase", passphrase: CovJBkFixture.phrase, cryptoType: "SR25519",
            substrateDerivationPath: "//covjbk", ethDerivationPath: DerivationPathConstants.defaultEthereum,
            backupAccountType: [.passphrase]
        )

        let screen = try restore(backup)

        let request = try XCTUnwrap(screen.interactor.requests.first)
        XCTAssertEqual(request.username, "Phrase")
        XCTAssertEqual(request.cryptoType, .sr25519)
        XCTAssertNil(request.defaultChainId)
        guard case let .mnemonic(data) = request.source else {
            return XCTFail("A phrase backup imports the words")
        }
        XCTAssertEqual(data.mnemonic.toString(), CovJBkFixture.phrase)
        XCTAssertEqual(data.substrateDerivationPath, "//covjbk")
        XCTAssertEqual(data.ethereumDerivationPath, DerivationPathConstants.defaultEthereum)
        XCTAssertEqual(data.substratePasswordRule, .nfkd)
        XCTAssertEqual(screen.view.stops, 1)
    }

    func testUntypedPhraseBackupWithANumericCryptoTypeUsesEmptyPaths() throws {
        let backup = OpenBackupAccount(name: "Legacy", address: "5Legacy", passphrase: CovJBkFixture.phrase, cryptoType: "1")

        let screen = try restore(backup)

        let request = try XCTUnwrap(screen.interactor.requests.first)
        XCTAssertEqual(request.cryptoType, .ed25519)
        guard case let .mnemonic(data) = request.source else {
            return XCTFail("A backup with words is read as a phrase backup")
        }
        XCTAssertEqual(data.substrateDerivationPath, "")
        XCTAssertEqual(data.ethereumDerivationPath, "")
    }

    func testPasswordRuleOfAnEarlierExtensionIsRestoredWhenTheBackupIsFiledUnderIt() throws {
        let path = "//0///\u{FB01}"
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: CovJBkFixture.phrase)
        let accounts = try SubstratePasswordRule.accounts(mnemonic: mnemonic, derivationPath: path, cryptoType: .sr25519)
        let nfc = try XCTUnwrap(accounts.first { $0.rule == .nfc })
        let backup = OpenBackupAccount(
            name: "Extension", address: nfc.address, passphrase: CovJBkFixture.phrase, cryptoType: "sr25519",
            substrateDerivationPath: path, backupAccountType: [.passphrase]
        )

        let screen = try restore(backup)

        guard case let .mnemonic(data) = try XCTUnwrap(screen.interactor.requests.first).source else {
            return XCTFail("A phrase backup imports the words")
        }
        XCTAssertGreaterThan(accounts.count, 1)
        XCTAssertEqual(data.substratePasswordRule, .nfc)
    }

    func testSeedBackupKeepsAnEthereumPathOnlyWithAnEthereumSeed() throws {
        let substrateOnly = try restore(OpenBackupAccount(
            name: "Seed", address: "5Seed", cryptoType: "ED25519", backupAccountType: [.seed],
            encryptedSeed: OpenBackupAccount.Seed(substrateSeed: "0x01", ethSeed: nil)
        ))
        guard case let .seed(first) = try XCTUnwrap(substrateOnly.interactor.requests.first).source else {
            return XCTFail("A seed backup imports the seeds")
        }
        XCTAssertEqual(first.substrateSeed, "0x01")
        XCTAssertNil(first.ethereumSeed)
        XCTAssertEqual(first.substrateDerivationPath, "")
        XCTAssertNil(first.ethereumDerivationPath)

        let withEthereum = try restore(OpenBackupAccount(
            name: "Seed", address: "5Seed", cryptoType: "ecdsa", substrateDerivationPath: "//s",
            encryptedSeed: OpenBackupAccount.Seed(substrateSeed: "0x02", ethSeed: "0x03")
        ))
        let request = try XCTUnwrap(withEthereum.interactor.requests.first)
        XCTAssertEqual(request.cryptoType, .ecdsa)
        guard case let .seed(second) = request.source else {
            return XCTFail("An untyped backup with a seed is read as a seed backup")
        }
        XCTAssertEqual(second.ethereumSeed, "0x03")
        XCTAssertEqual(second.substrateDerivationPath, "//s")
        XCTAssertEqual(second.ethereumDerivationPath, "")
    }

    func testJsonBackupUsesTheTypedPasswordForEachFile() throws {
        let both = try restore(OpenBackupAccount(
            name: "Json", address: "5Json", cryptoType: "SR25519", backupAccountType: [.json],
            json: OpenBackupAccount.Json(substrateJson: "{\"s\":1}", ethJson: "{\"e\":1}")
        ), password: "pw")
        guard case let .keystore(files) = try XCTUnwrap(both.interactor.requests.first).source else {
            return XCTFail("A JSON backup imports the files")
        }
        XCTAssertEqual(files.substrateKeystore, "{\"s\":1}")
        XCTAssertEqual(files.ethereumKeystore, "{\"e\":1}")
        XCTAssertEqual(files.substratePassword, "pw")
        XCTAssertEqual(files.ethereumPassword, "pw")

        let substrateOnly = try restore(OpenBackupAccount(
            name: "Json", address: "5Json", cryptoType: "SR25519",
            json: OpenBackupAccount.Json(substrateJson: "{\"s\":2}", ethJson: nil)
        ), password: "pw")
        guard case let .keystore(file) = try XCTUnwrap(substrateOnly.interactor.requests.first).source else {
            return XCTFail("An untyped backup with a file is read as a JSON backup")
        }
        XCTAssertNil(file.ethereumKeystore)
        XCTAssertNil(file.ethereumPassword)
    }

    func testUnreadableBackupsShowTheCommonError() throws {
        let unreadable = [
            OpenBackupAccount(name: "Empty", address: "5Empty", cryptoType: "SR25519"),
            OpenBackupAccount(name: "Crypto", address: "5Crypto", passphrase: CovJBkFixture.phrase, cryptoType: "bogus"),
            OpenBackupAccount(address: "5Nameless", passphrase: CovJBkFixture.phrase, cryptoType: "SR25519"),
            OpenBackupAccount(name: "Words", address: "5Words", passphrase: "not a real phrase", cryptoType: "SR25519"),
            OpenBackupAccount(name: "Seed", address: "5Seed", cryptoType: "SR25519", backupAccountType: [.seed]),
            OpenBackupAccount(name: "Json", address: "5Json", cryptoType: "SR25519", backupAccountType: [.json]),
            OpenBackupAccount(name: "Unknown", address: "5Unknown", cryptoType: "SR25519", backupAccountType: [])
        ]

        for backup in unreadable {
            assertCommonError(try restore(backup))
        }
    }
}
