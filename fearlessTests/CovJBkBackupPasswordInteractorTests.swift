import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFCloudStorage
import SSFModels
import SSFUtils
@testable import fearless

final class CovJBkKeystoreImportService: KeystoreImportServiceProtocol {
    private(set) var observers = 0

    var definition: KeystoreDefinition? { nil }
    func handle(url _: URL) -> Bool { false }
    func add(observer _: KeystoreImportObserver) { observers += 1 }
    func remove(observer _: KeystoreImportObserver) { observers -= 1 }
    func clear() {}
}

final class CovJBkBackupPasswordOutput: BackupPasswordInteractorOutput {
    private(set) var backups: [Result<OpenBackupAccount, Error>] = []
    private(set) var importErrors: [Error] = []
    private(set) var completions = 0
    private(set) var googleIssues = 0

    func didReceiveBackup(result: Result<OpenBackupAccount, Error>) { backups.append(result) }
    func didReceiveAccountImport(error: Error) { importErrors.append(error) }
    func didCompleteAccountImport() { completions += 1 }
    func showGoogleIssueError() { googleIssues += 1 }
}

final class CovJBkBackupPasswordInteractorTests: XCTestCase {
    private struct Parts {
        let interactor: BackupPasswordInteractor
        let output: CovJBkBackupPasswordOutput
        let cloud: CovJBkCloudStorage
        let events: CovJBkEventCenter
    }

    private func makeParts(withCloud: Bool = true) -> Parts {
        let events = CovJBkEventCenter()
        let interactor = BackupPasswordInteractor(
            accountOperationFactory: MetaAccountOperationFactory(keystore: InMemoryKeychain()),
            accountRepository: AnyDataProviderRepository(CovJMemoryRepository<MetaAccountModel>()),
            operationManager: OperationManager(),
            settings: SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue()),
            keystoreImportService: CovJBkKeystoreImportService(),
            eventCenter: events,
            defaultSource: .mnemonic
        )
        let cloud = CovJBkCloudStorage()
        if withCloud {
            interactor.cloudStorage = cloud
        }
        let output = CovJBkBackupPasswordOutput()
        interactor.setup(with: output)
        return Parts(interactor: interactor, output: output, cloud: cloud, events: events)
    }

    func testDownloadedBackupIsHandedOn() throws {
        let parts = makeParts()
        parts.cloud.importResult = .success(OpenBackupAccount(name: "Restored", address: "5Restored"))

        parts.interactor.importBackup(account: OpenBackupAccount(address: "5Chosen"), password: "pw")

        XCTAssertTrue(CovJWait.until { parts.output.backups.count == 1 })
        XCTAssertEqual(try XCTUnwrap(parts.output.backups.first).get().name, "Restored")
        XCTAssertEqual(parts.cloud.calls, ["import:5Chosen:pw"])
        XCTAssertEqual(parts.output.googleIssues, 0)
    }

    func testSignedOutDriveDisconnectsAndAsksToSignInAgain() {
        let parts = makeParts()
        parts.cloud.importResult = .failure(CloudStorageServiceError.notAuthorized)

        parts.interactor.importBackup(account: OpenBackupAccount(address: "5Chosen"), password: "pw")

        XCTAssertTrue(CovJWait.until { parts.output.googleIssues == 1 })
        XCTAssertEqual(parts.cloud.calls, ["import:5Chosen:pw", "disconnect"])
        XCTAssertTrue(parts.output.backups.isEmpty)
    }

    func testBackupProblemsAreReportedWithoutDisconnecting() {
        let parts = makeParts()
        let problems: [CloudStorageServiceError] = [.incorectPassword, .incorectJson, .notFound, .readbackMismatch]

        for (index, problem) in problems.enumerated() {
            parts.cloud.importResult = .failure(problem)
            parts.interactor.importBackup(account: OpenBackupAccount(address: "5Chosen"), password: "pw")
            XCTAssertTrue(CovJWait.until { parts.output.backups.count == index + 1 })
        }

        let reported = parts.output.backups.compactMap { result -> CloudStorageServiceError? in
            if case let .failure(error) = result { return error as? CloudStorageServiceError }
            return nil
        }
        XCTAssertEqual(reported, problems)
        XCTAssertFalse(parts.cloud.calls.contains("disconnect"))
        XCTAssertEqual(parts.output.googleIssues, 0)
    }

    func testOtherErrorsDisconnectAndAskToSignInAgain() {
        let parts = makeParts()
        parts.cloud.importResult = .failure(CovJError("network"))

        parts.interactor.importBackup(account: OpenBackupAccount(address: "5Chosen"), password: "pw")

        XCTAssertTrue(CovJWait.until { parts.output.googleIssues == 1 })
        XCTAssertEqual(parts.cloud.calls.last, "disconnect")
    }

    func testSignInIsRequestedFromDrive() {
        let parts = makeParts()

        parts.interactor.signInIfNeeded()

        XCTAssertTrue(CovJWait.until { parts.cloud.calls == ["signIn"] })
    }

    func testWithoutCloudStorageNothingIsDownloaded() {
        let parts = makeParts(withCloud: false)

        parts.interactor.importBackup(account: OpenBackupAccount(address: "5Chosen"), password: "pw")
        parts.interactor.signInIfNeeded()
        CovJWait.drain(0.2)

        XCTAssertTrue(parts.output.backups.isEmpty)
        XCTAssertEqual(parts.output.googleIssues, 0)
        XCTAssertTrue(parts.cloud.calls.isEmpty)
    }

    func testFailedImportIsReported() {
        let parts = makeParts()

        parts.interactor.importAccountUsingOperation(ClosureOperation<MetaAccountModel> { throw CovJError("import") })

        XCTAssertTrue(CovJWait.until { parts.output.importErrors.count == 1 })
        XCTAssertEqual(parts.output.importErrors.first as? CovJError, CovJError("import"))
        XCTAssertEqual(parts.output.completions, 0)
    }

    func testImportedWalletIsSavedAsBackedUpSelectedAndAnnounced() throws {
        let parts = makeParts()
        let wallet = CovJBkFixture.wallet(name: "Restored")

        parts.interactor.importAccountUsingOperation(ClosureOperation { wallet })

        XCTAssertTrue(CovJWait.until(timeout: 5) { parts.output.completions == 1 })
        let event = try XCTUnwrap(parts.events.events.compactMap { $0 as? SelectedAccountChanged }.first)
        XCTAssertEqual(event.account.metaId, wallet.metaId)
        XCTAssertTrue(event.account.hasBackup)
        XCTAssertTrue(parts.output.importErrors.isEmpty)
    }
}

final class CovJBkBackupPasswordRoutingTests: XCTestCase {
    func testWalletImportedScreenIsPushed() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let accounts = [BackupAccount(account: OpenBackupAccount(name: "Pushed", address: "5Pushed"), current: true)]

        BackupPasswordRouter().showWalletImportedScreen(backupAccounts: accounts, from: host)

        let imported = try XCTUnwrap(host.top as? BackupWalletImportedViewController)
        imported.loadViewIfNeeded()
        XCTAssertEqual(imported.rootView.walletNameLabel.text, "Pushed")
        XCTAssertTrue(imported.rootView.importMoreButton.isHidden)
    }

    func testAssemblyNeedsTheKeystoreImportService() {
        let service: KeystoreImportServiceProtocol? = URLHandlingService.shared.findService()
        let accounts = [BackupAccount(account: OpenBackupAccount(address: "5Assembly"), current: true)]

        let module = BackupPasswordAssembly.configureModule(backupAccounts: accounts)

        if service == nil {
            XCTAssertNil(module, "Without the keystore import service no restore screen is built")
        } else {
            XCTAssertTrue(module?.view is BackupPasswordViewController)
            XCTAssertTrue(module?.input is BackupPasswordPresenter)
        }
    }
}
