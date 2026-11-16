import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFCloudStorage
import SSFModels
@testable import fearless

final class CovJBkJsonExporter: KeystoreExportWrapperProtocol {
    private let lock = NSLock()
    private var recorded: [(address: String, metaId: String, password: String?)] = []

    var calls: [(address: String, metaId: String, password: String?)] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    static func json(for address: String) -> String { #"{"covjbk":"\#(address)"}"# }

    func export(
        chainAccount _: ChainAccountResponse,
        password: String?,
        address: String,
        metaId: String,
        accountId _: AccountId?,
        genesisHash _: String?
    ) throws -> Data {
        lock.lock()
        recorded.append((address, metaId, password))
        lock.unlock()
        return Data(Self.json(for: address).utf8)
    }
}

final class CovJBkCreatePasswordOutput: BackupCreatePasswordInteractorOutput {
    private let lock = NSLock()
    private var receivedErrors: [Error] = []
    private var receivedCompletions: [[ChainAccountModel]] = []

    var errors: [Error] {
        lock.lock()
        defer { lock.unlock() }
        return receivedErrors
    }

    var completions: [[ChainAccountModel]] {
        lock.lock()
        defer { lock.unlock() }
        return receivedCompletions
    }

    func didReceive(error: Error) {
        lock.lock()
        receivedErrors.append(error)
        lock.unlock()
    }

    func didComplete(accountsNotRestored: [ChainAccountModel]) {
        lock.lock()
        receivedCompletions.append(accountsNotRestored)
        lock.unlock()
    }
}

/// A navigation stack's controller seen as a module view.
final class CovJBkControllerView: ControllerBackedProtocol {
    let controller: UIViewController
    var isSetup: Bool { true }

    init(_ controller: UIViewController) {
        self.controller = controller
    }
}

final class CovJBkBackupCreatePasswordInteractorTests: XCTestCase {
    private let password = "covjbk-password"

    private struct Parts {
        let interactor: BackupCreatePasswordInteractor
        let output: CovJBkCreatePasswordOutput
        let exporter: CovJBkJsonExporter
        let secrets: CovJBkSecretManager
        let repository: CovJMemoryRepository<MetaAccountModel>
        let wallet: MetaAccountModel
        let chain: ChainModel
    }

    private func makeParts(options: [ExportOption] = [.keystore], single: Bool = false) -> Parts {
        let wallet = CovJBkFixture.wallet(name: "Drive wallet")
        let chain = CovJFixture.chain(id: "covjbk-drive", name: "Drive", addressPrefix: 0)
        let accounts = [wallet.fetch(for: chain.accountRequest())].compactMap { $0 }.map {
            ChainAccountInfo(chain: chain, account: $0)
        }
        let exportFlow: ExportFlow = single
            ? .single(chain: chain, address: wallet.backupAddress, wallet: wallet)
            : .multiple(wallet: wallet, accounts: accounts)
        let repository = CovJMemoryRepository<MetaAccountModel>([wallet])
        let exporter = CovJBkJsonExporter()
        let secrets = CovJBkSecretManager()
        let keystore = InMemoryKeychain()
        let interactor = BackupCreatePasswordInteractor(
            createPasswordFlow: .backupWallet(flow: exportFlow, options: options),
            accountOperationFactory: MetaAccountOperationFactory(keystore: keystore),
            accountRepository: AnyDataProviderRepository(repository),
            settings: SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue()),
            operationManager: OperationManager(),
            eventCenter: CovJBkEventCenter(),
            secretManager: secrets,
            keystore: keystore,
            exportJsonWrapper: exporter
        )
        let output = CovJBkCreatePasswordOutput()
        interactor.setup(with: output)
        return Parts(
            interactor: interactor, output: output, exporter: exporter, secrets: secrets,
            repository: repository, wallet: wallet, chain: chain
        )
    }

    func testPinIsCheckedUnderThePincodeTag() {
        let parts = makeParts()

        XCTAssertFalse(parts.interactor.hasPincode())
        parts.secrets.hasSecret = true
        XCTAssertTrue(parts.interactor.hasPincode())
        XCTAssertEqual(parts.secrets.checked, [fearless.KeystoreTag.pincode.rawValue, fearless.KeystoreTag.pincode.rawValue])
    }

    func testSingleAccountBackupIsRefused() {
        let parts = makeParts(single: true)

        parts.interactor.createAndBackupAccount(password: password)

        XCTAssertEqual(parts.output.errors.map { $0 as? BackupCreatePasswordError }, [.incompleteBackupMaterial])
        XCTAssertTrue(parts.exporter.calls.isEmpty)
    }

    func testWalletWithoutUsableMaterialIsRefused() {
        let parts = makeParts(options: [])

        parts.interactor.createAndBackupAccount(password: password)

        XCTAssertTrue(CovJWait.until { parts.output.errors.count == 1 })
        XCTAssertEqual(parts.output.errors.first as? BackupCreatePasswordError, .incompleteBackupMaterial)
    }

    func testJsonBackupNeedsCloudStorage() {
        let parts = makeParts()

        parts.interactor.createAndBackupAccount(password: password)

        XCTAssertTrue(CovJWait.until { parts.output.errors.count == 1 })
        XCTAssertEqual(parts.output.errors.first as? BackupCreatePasswordError, .unavailableCloudStorage)
        XCTAssertEqual(parts.exporter.calls.map(\.metaId), [parts.wallet.metaId])
        XCTAssertEqual(parts.exporter.calls.first?.password, password)
    }

    func testJsonBackupIsUploadedReadBackAndTheWalletMarkedBackedUp() throws {
        let parts = makeParts()
        let cloud = CovJBkCloudStorage()
        parts.interactor.cloudStorage = cloud

        parts.interactor.createAndBackupAccount(password: password)

        XCTAssertTrue(CovJWait.until(timeout: 5) { parts.output.completions.count == 1 })
        XCTAssertEqual(parts.output.completions.first?.count, 0)
        XCTAssertTrue(parts.output.errors.isEmpty)
        XCTAssertEqual(cloud.calls, ["saveAndImport:\(password)"])
        let uploaded = try XCTUnwrap(cloud.saved.first)
        let address = try XCTUnwrap(parts.exporter.calls.first?.address)
        XCTAssertEqual(uploaded.backupAccountType, [.json])
        XCTAssertEqual(uploaded.json?.substrateJson, CovJBkJsonExporter.json(for: address))
        XCTAssertNil(uploaded.json?.ethJson)
        XCTAssertEqual(uploaded.address, parts.wallet.backupAddress)
        XCTAssertEqual(uploaded.name, "Drive wallet")
        XCTAssertEqual(uploaded.cryptoType, "SR25519")
        XCTAssertNil(uploaded.passphrase)
        XCTAssertEqual(parts.repository.items.first?.hasBackup, true)
    }

    func testChangedReadbackIsReportedAndTheWalletStaysUnmarked() {
        let parts = makeParts()
        let cloud = CovJBkCloudStorage()
        cloud.readback = { account in
            var changed = account
            changed.name = "Someone else"
            return changed
        }
        parts.interactor.cloudStorage = cloud

        parts.interactor.createAndBackupAccount(password: password)

        XCTAssertTrue(CovJWait.until(timeout: 5) { parts.output.errors.count == 1 })
        XCTAssertEqual(parts.output.errors.first as? BackupCreatePasswordError, .cloudBackupReadbackMismatch)
        XCTAssertEqual(parts.repository.saveCount, 0)
        XCTAssertEqual(parts.repository.items.first?.hasBackup, false)
    }

    func testDriveFailureIsReported() {
        let parts = makeParts()
        let cloud = CovJBkCloudStorage()
        cloud.saveError = CloudStorageServiceError.notAuthorized
        parts.interactor.cloudStorage = cloud

        parts.interactor.createAndBackupAccount(password: password)

        XCTAssertTrue(CovJWait.until(timeout: 5) { parts.output.errors.count == 1 })
        XCTAssertEqual(parts.output.errors.first as? CloudStorageServiceError, .notAuthorized)
        XCTAssertTrue(parts.output.completions.isEmpty)
    }

    func testFailingWalletStoreIsReportedAfterTheUpload() {
        let parts = makeParts()
        let cloud = CovJBkCloudStorage()
        parts.interactor.cloudStorage = cloud
        parts.repository.failure = CovJError("store")

        parts.interactor.createAndBackupAccount(password: password)

        XCTAssertTrue(CovJWait.until(timeout: 5) { parts.output.errors.count == 1 })
        XCTAssertEqual(parts.output.errors.first as? CovJError, CovJError("store"))
        XCTAssertEqual(cloud.saved.count, 1)
        XCTAssertTrue(parts.output.completions.isEmpty)
    }
}

final class CovJBkBackupCreatePasswordRoutingTests: XCTestCase {
    func testPinSetupReplacesTheRootThroughTheAnimator() {
        let router = BackupCreatePasswordRouter()
        let animator = CovJBkRootAnimator()
        router.rootAnimator = animator

        router.showPinSetup()

        XCTAssertEqual(animator.controllers.count, 1)
        XCTAssertNotNil(animator.controllers.first as? PinSetupViewProtocol)
    }

    func testPopLeavesThePushedScreen() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let pushed = UIViewController()
        host.navigation.pushViewController(pushed, animated: false)

        BackupCreatePasswordRouter().pop(from: CovJBkControllerView(pushed))

        XCTAssertTrue(CovJWait.until { host.navigation.viewControllers.count == 1 })
        XCTAssertTrue(host.top === host.controller)
    }

    func testDismissClosesThePresentedNavigation() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let presented = UIViewController()
        host.controller.present(UINavigationController(rootViewController: presented), animated: false)
        XCTAssertNotNil(host.presented)

        BackupCreatePasswordRouter().dismiss(from: CovJBkControllerView(presented))

        XCTAssertTrue(CovJWait.until { host.presented == nil })
    }

    func testAssemblyBuildsThePasswordScreen() throws {
        let flow = BackupCreatePasswordFlow.backupWallet(
            flow: .multiple(wallet: CovJBkFixture.wallet(), accounts: []),
            options: [.keystore]
        )

        let module = try XCTUnwrap(BackupCreatePasswordAssembly.configureModule(with: flow))

        XCTAssertTrue(module.view is BackupCreatePasswordViewController)
        XCTAssertTrue(module.input is BackupCreatePasswordPresenter)
    }
}
