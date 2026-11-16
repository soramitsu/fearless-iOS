import XCTest
import UIKit
import SoraFoundation
import SSFCloudStorage
import SSFModels
@testable import fearless

final class CovJBkCreatePasswordView: CovJBkLoadableView, BackupCreatePasswordViewInput {
    private(set) var passwordViewModel: InputViewModelProtocol?
    private(set) var confirmationViewModel: InputViewModelProtocol?
    private(set) var matches: [Bool] = []

    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol) { passwordViewModel = viewModel }
    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol) { confirmationViewModel = viewModel }
    func setPassword(isMatched: Bool) { matches.append(isMatched) }
}

final class CovJBkCreatePasswordInteractor: BackupCreatePasswordInteractorInput {
    var hasPin = true
    private(set) weak var output: BackupCreatePasswordInteractorOutput?
    private(set) var passwords: [String] = []

    func setup(with output: BackupCreatePasswordInteractorOutput) { self.output = output }
    func createAndBackupAccount(password: String) { passwords.append(password) }
    func hasPincode() -> Bool { hasPin }
}

final class CovJBkCreatePasswordRouter: BackupCreatePasswordRouterInput {
    private(set) var pinSetups = 0
    private(set) var pops = 0
    private(set) var dismissals = 0
    private(set) var sheets: [SheetAlertPresentableViewModel] = []
    private(set) var errors: [Error] = []

    func showPinSetup() { pinSetups += 1 }
    func pop(from _: ControllerBackedProtocol?) { pops += 1 }
    func dismiss(from _: ControllerBackedProtocol?) { dismissals += 1 }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheets.append(viewModel)
    }

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return true
    }
}

final class CovJBkCreatePasswordModuleOutput: BackupCreatePasswordModuleOutput {
    private(set) var completions = 0
    func backupDidComplete() { completions += 1 }
}

final class CovJBkBackupCreatePasswordPresenterTests: XCTestCase {
    private var languages: [String]? { CovJBkFixture.languages }

    private struct Step {
        let presenter: BackupCreatePasswordPresenter
        let view: CovJBkCreatePasswordView
        let interactor: CovJBkCreatePasswordInteractor
        let router: CovJBkCreatePasswordRouter
        let moduleOutput: CovJBkCreatePasswordModuleOutput
    }

    private func makeStep(flow: BackupCreatePasswordFlow? = nil) throws -> Step {
        let view = CovJBkCreatePasswordView()
        let interactor = CovJBkCreatePasswordInteractor()
        let router = CovJBkCreatePasswordRouter()
        let moduleOutput = CovJBkCreatePasswordModuleOutput()
        let presenter = BackupCreatePasswordPresenter(
            logger: Logger.shared,
            flow: flow ?? .backupWallet(flow: .multiple(wallet: CovJBkFixture.wallet(), accounts: []), options: [.mnemonic]),
            moduleOutput: moduleOutput,
            interactor: interactor,
            router: router,
            localizationManager: try CovJBkFixture.localization()
        )
        presenter.didLoad(view: view)
        return Step(presenter: presenter, view: view, interactor: interactor, router: router, moduleOutput: moduleOutput)
    }

    private func type(_ password: String, confirmation: String, in step: Step) throws {
        try XCTUnwrap(step.view.passwordViewModel).inputHandler.changeValue(to: password)
        try XCTUnwrap(step.view.confirmationViewModel).inputHandler.changeValue(to: confirmation)
    }

    private func sheetAfterError(_ error: Error, in step: Step) throws -> SheetAlertPresentableViewModel {
        let count = step.router.sheets.count
        step.presenter.didReceive(error: error)
        XCTAssertTrue(CovJWait.until { step.router.sheets.count == count + 1 })
        return try XCTUnwrap(step.router.sheets.last)
    }

    func testLoadingHandsOverBothInputsWithTheEightCharacterRule() throws {
        let step = try makeStep()

        XCTAssertTrue(step.interactor.output === step.presenter)
        let password = try XCTUnwrap(step.view.passwordViewModel)
        let confirmation = try XCTUnwrap(step.view.confirmationViewModel)
        password.inputHandler.changeValue(to: "short")
        XCTAssertFalse(password.inputHandler.completed)
        password.inputHandler.changeValue(to: "12345678")
        XCTAssertTrue(password.inputHandler.completed)
        XCTAssertFalse(confirmation.inputHandler.completed)
        confirmation.inputHandler.changeValue(to: "x")
        XCTAssertTrue(confirmation.inputHandler.completed)
        step.presenter.applyLocalization()
        XCTAssertTrue(step.router.sheets.isEmpty)
    }

    func testMismatchedPasswordsAreFlaggedAndNothingIsUploaded() throws {
        let step = try makeStep()
        try type("password-one", confirmation: "password-two", in: step)

        step.presenter.didTapContinueButton()

        XCTAssertEqual(step.view.starts, 1)
        XCTAssertEqual(step.view.matches, [false])
        XCTAssertTrue(step.interactor.passwords.isEmpty)
    }

    func testMatchingPasswordsStartTheBackupAndBackPops() throws {
        let step = try makeStep()
        try type("password-one", confirmation: "password-one", in: step)

        step.presenter.didTapContinueButton()
        step.presenter.didTapBackButton()

        XCTAssertEqual(step.interactor.passwords, ["password-one"])
        XCTAssertTrue(step.view.matches.isEmpty)
        XCTAssertEqual(step.router.pops, 1)
    }

    func testWalletsTheBackupCannotHoldLeadBackToTheOtherOptions() throws {
        let cases: [(BackupCreatePasswordError, String)] = [
            (.nativeTonWalletNotSupported, R.string.localizable.backupGoogleTonUnsupportedMessage(preferredLanguages: languages)),
            (.walletWithoutSubstrateAccount, R.string.localizable.backupGoogleSubstrateUnsupportedMessage(preferredLanguages: languages)),
            (.incompleteBackupMaterial, R.string.localizable.backupGoogleMaterialMessage(preferredLanguages: languages)),
            (.unverifiedRecoveryPhrase, R.string.localizable.backupGoogleMaterialMessage(preferredLanguages: languages))
        ]
        let step = try makeStep()

        for (index, (error, message)) in cases.enumerated() {
            let sheet = try sheetAfterError(error, in: step)
            XCTAssertEqual(sheet.title, R.string.localizable.backupGoogleNotCreatedTitle(preferredLanguages: languages))
            XCTAssertEqual(sheet.message, message, "\(error)")
            XCTAssertEqual(sheet.actions.map(\.title), [R.string.localizable.commonClose(preferredLanguages: languages)])
            XCTAssertNil(sheet.closeAction)
            sheet.actions.first?.handler?()
            XCTAssertEqual(step.router.pops, index + 1)
        }
        XCTAssertEqual(step.view.stops, cases.count)
        XCTAssertTrue(step.interactor.passwords.isEmpty)
    }

    func testReadbackProblemsCanBeRetried() throws {
        let errors: [Error] = [
            BackupCreatePasswordError.cloudBackupReadbackMismatch,
            CloudStorageServiceError.readbackMismatch,
            CloudStorageServiceError.incorectJson,
            CloudStorageServiceError.incorectPassword
        ]
        let step = try makeStep()
        try type("password-one", confirmation: "password-one", in: step)

        for (index, error) in errors.enumerated() {
            let sheet = try sheetAfterError(error, in: step)
            XCTAssertEqual(sheet.message, R.string.localizable.backupGoogleReadbackMessage(preferredLanguages: languages))
            XCTAssertEqual(sheet.actions.map(\.title), [R.string.localizable.tryAgain(preferredLanguages: languages)])
            XCTAssertEqual(sheet.closeAction, R.string.localizable.commonClose(preferredLanguages: languages))
            sheet.actions.first?.handler?()
            XCTAssertEqual(step.view.starts, index + 1)
            XCTAssertEqual(step.interactor.passwords.count, index + 1)
        }
        XCTAssertEqual(Set(step.interactor.passwords), ["password-one"])
        XCTAssertEqual(step.router.pops, 0)
    }

    func testOtherFailuresOfferAGoogleRetryAndStopLoadingWhenClosed() throws {
        let step = try makeStep()

        let sheet = try sheetAfterError(CovJError("google"), in: step)

        XCTAssertEqual(sheet.title, R.string.localizable.noAccessToGoogle(preferredLanguages: languages))
        XCTAssertNil(sheet.message)
        XCTAssertNil(sheet.closeAction)
        XCTAssertEqual(sheet.actions.map(\.title), [R.string.localizable.tryAgain(preferredLanguages: languages)])
        XCTAssertEqual(step.view.stops, 1)
        sheet.actions.first?.handler?()
        XCTAssertEqual(step.interactor.passwords, [""])
        sheet.dismissCompletion?()
        XCTAssertEqual(step.view.stops, 2)
    }

    func testCreatedWalletEndsInTheAppWhenAPinExistsOrAsksForOne() throws {
        let flow = BackupCreatePasswordFlow.createWallet(try CovJBkFixture.mnemonicRequest())
        let withPin = try makeStep(flow: flow)

        withPin.presenter.didComplete(accountsNotRestored: [])

        XCTAssertEqual(withPin.view.stops, 1)
        XCTAssertEqual(withPin.router.dismissals, 1)
        XCTAssertEqual(withPin.router.pinSetups, 0)
        XCTAssertEqual(withPin.moduleOutput.completions, 0)

        let withoutPin = try makeStep(flow: flow)
        withoutPin.interactor.hasPin = false

        withoutPin.presenter.didComplete(accountsNotRestored: [])

        XCTAssertEqual(withoutPin.router.pinSetups, 1)
        XCTAssertEqual(withoutPin.router.dismissals, 0)
    }

    func testBackupLeavingAnAccountOutSaysSoBeforeFinishing() throws {
        let step = try makeStep()
        let account = CovJBkFixture.chainAccount(chainId: UniversalWalletRegistry.taira.chainId, seed: 5)

        step.presenter.didComplete(accountsNotRestored: [account])

        let sheet = try XCTUnwrap(step.router.sheets.last)
        XCTAssertEqual(sheet.title, R.string.localizable.backupGooglePartialTitle(preferredLanguages: languages))
        XCTAssertEqual(sheet.message, R.string.localizable.backupGooglePartialMessage(
            GoogleDriveBackupContent.displayLine(for: account), preferredLanguages: languages
        ))
        XCTAssertEqual(sheet.closeAction, R.string.localizable.commonOk(preferredLanguages: languages))
        XCTAssertTrue(sheet.actions.isEmpty)
        XCTAssertEqual(step.moduleOutput.completions, 0)
        sheet.dismissCompletion?()
        XCTAssertEqual(step.moduleOutput.completions, 1)
        XCTAssertEqual(step.router.pops, 1)
    }
}
