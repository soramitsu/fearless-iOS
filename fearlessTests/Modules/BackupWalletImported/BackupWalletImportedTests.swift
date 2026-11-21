import RobinHood
import SoraFoundation
import SoraKeystore
import SSFCloudStorage
import SSFModels
import UIKit
import XCTest
@testable import fearless

@MainActor
final class BackupWalletImportedTests: XCTestCase {
    /// A phrase wallet upgraded to 4.2 holds Bitcoin, Solana, TON and Taira rows that the phrase derives
    /// (`UniversalWalletAccountProvisioning`). They must not raise the "replaced key pair" warning.
    func testPhraseDerivedNetworkAccountDoesNotRaiseTheReplacedKeyWarning() throws {
        let account = chainAccount(UniversalWalletRegistry.bitcoinMainnet.chainId)
        let fixture = try presenter(wallet: AccountGenerator.generateMetaAccount(with: [account]))
        fixture.subject.viewDidAppear()
        XCTAssertTrue(fixture.router.sheets.isEmpty)
        XCTAssertEqual(fixture.interactor.appearances, 1, "The backup lookup starts without a warning first")
    }

    func testMixedWalletWarningNamesOnlyTheExplicitlyReplacedNetwork() throws {
        let chain = ChainModel(
            rank: nil, disabled: false, chainId: "independent-substrate", paraId: nil,
            name: "Independent Network", xcm: nil, nodes: [], addressPrefix: 42,
            icon: nil, options: nil, iosMinAppVersion: nil, identityChain: nil
        )
        let accounts: Set<ChainAccountModel> = [
            chainAccount(chain.chainId), chainAccount(UniversalWalletRegistry.solanaMainnet.chainId)
        ]
        let fixture = try presenter(wallet: AccountGenerator.generateMetaAccount(with: accounts))
        fixture.subject.didReceive(chains: [chain])
        fixture.subject.viewDidAppear()
        let message = try XCTUnwrap(fixture.router.sheets.first?.message)
        XCTAssertTrue(message.contains("Independent Network"))
        XCTAssertEqual(fixture.router.sheets.count, 1)
        XCTAssertEqual(fixture.interactor.appearances, 0, "The warning comes before the backup lookup")
    }

    func testMissingGoogleConfigurationEndsLoadingAndKeepsPhraseExportUsable() throws {
        let fixture = try presenter(wallet: AccountGenerator.generateMetaAccount())
        fixture.subject.didReceive(options: [.mnemonic])
        fixture.subject.viewDidAppear()
        XCTAssertEqual(fixture.view.starts, 1)
        fixture.subject.didReceiveBackupAccounts(result: .failure(
            GoogleDrivePasskeyBackupError.unavailableConfiguration
        ))
        XCTAssertEqual(fixture.view.stops, 1)
        XCTAssertTrue(fixture.router.sheets.isEmpty)
        fixture.subject.didSelectRowAt(IndexPath(row: 0, section: 1))
        XCTAssertEqual(fixture.router.mnemonicExports, 1)
        fixture.subject.viewDidAppear()
        XCTAssertEqual(fixture.interactor.appearances, 1, "An unavailable provider must not reload forever")
    }

    func testOrdinaryCloudFailureStillOffersRetryAndStopsLoading() throws {
        let fixture = try presenter(wallet: AccountGenerator.generateMetaAccount())
        fixture.subject.viewDidAppear()
        fixture.subject.didReceiveBackupAccounts(result: .failure(BackupLookupFailure.network))
        XCTAssertEqual(fixture.view.stops, 1)
        XCTAssertEqual(fixture.router.sheets.count, 1)
        fixture.router.sheets[0].actions.first?.handler?()
        XCTAssertEqual(fixture.interactor.appearances, 2)
    }

    func testInvalidGoogleConfigurationNeverInvokesCloudService() async {
        let output = BackupLookupOutput()
        let cloud = BackupLookupCloud()
        let subject = interactor(output: output) {
            _ = try GoogleDriveBackupOAuthConfiguration(info: [:])
        }
        subject.cloudStorage = cloud
        subject.viewDidAppear()
        await fulfillment(of: [output.completed], timeout: 3)
        XCTAssertEqual(output.failure as? GoogleDrivePasskeyBackupError, .unavailableConfiguration)
        XCTAssertEqual(cloud.lookups, 0)
        XCTAssertEqual(cloud.disconnects, 0)
        XCTAssertTrue(output.wasMainThread)
    }

    func testMissingCloudServiceReportsFailureInsteadOfLeavingLoadingPending() async {
        let output = BackupLookupOutput()
        let subject = interactor(output: output, validate: {})
        subject.viewDidAppear()
        await fulfillment(of: [output.completed], timeout: 3)
        XCTAssertEqual(output.failure as? GoogleDrivePasskeyBackupError, .unavailableConfiguration)
        XCTAssertTrue(output.wasMainThread)
    }

    func testConfiguredCloudServiceReturnsItsLookupResult() async {
        let output = BackupLookupOutput()
        let cloud = BackupLookupCloud()
        let subject = interactor(output: output, validate: {})
        subject.cloudStorage = cloud
        subject.viewDidAppear()
        await fulfillment(of: [output.completed], timeout: 3)
        XCTAssertNil(output.failure)
        XCTAssertEqual(cloud.lookups, 1)
        XCTAssertEqual(output.accounts?.count, 0)
        XCTAssertTrue(output.wasMainThread)
    }

    func testMissingCloudServiceCannotReportSuccessfulDeletion() async {
        let output = BackupLookupOutput()
        let subject = interactor(output: output, validate: {})
        subject.removeBackupFromGoogle()
        await fulfillment(of: [output.completed], timeout: 3)
        XCTAssertEqual(output.failure as? GoogleDrivePasskeyBackupError, .unavailableConfiguration)
        XCTAssertTrue(output.wasMainThread)
    }

    private func chainAccount(_ chainId: String) -> ChainAccountModel {
        ChainAccountModel(
            chainId: chainId, accountId: Data(repeating: 1, count: 32),
            publicKey: Data(repeating: 1, count: 32), cryptoType: 0, ethereumBased: false
        )
    }

    private func presenter(wallet: fearless.MetaAccountModel) throws -> BackupPresenterFixture {
        let router = BackupRecoveryRouter()
        let interactor = BackupRecoveryInteractor()
        let view = BackupRecoveryView()
        let subject = try BackupWalletPresenter(
            wallet: wallet, interactor: interactor, router: router, logger: Logger.shared,
            localizationManager: XCTUnwrap(LocalizationManager(localization: "en")),
            viewModelFactory: BackupRecoveryViewModelFactory()
        )
        subject.didLoad(view: view)
        return BackupPresenterFixture(subject: subject, router: router, interactor: interactor, view: view)
    }

    private func interactor(
        output: BackupLookupOutput, validate: @escaping () throws -> Void
    ) -> BackupWalletInteractor {
        let subject = BackupWalletInteractor(
            wallet: AccountGenerator.generateMetaAccount(), walletBalanceSubscriptionAdapter: BackupLookupNoBalances(),
            availableExportOptionsProvider: AvailableExportOptionsProvider(keystore: InMemoryKeychain()),
            chainRepository: AnyDataProviderRepository(BackupLookupRepository()),
            operationManager: OperationManager(), validateCloudConfiguration: validate
        )
        subject.setup(with: output)
        return subject
    }
}

private struct BackupPresenterFixture {
    let subject: BackupWalletPresenter
    let router: BackupRecoveryRouter
    let interactor: BackupRecoveryInteractor
    let view: BackupRecoveryView
}

private enum BackupLookupFailure: Error { case network }

private struct BackupLookupNoBalances: WalletBalanceSubscriptionAdapterProtocol {
    func subscribeWalletBalance(wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func subscribeWalletsBalances(listener _: WalletBalanceSubscriptionListener) {}
    func subscribeChainAssetBalance(
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset,
        listener _: WalletBalanceSubscriptionListener
    ) {}

    func subscribeChainAssetsBalance(
        chainAssets _: [ChainAsset],
        wallet _: MetaAccountModel,
        listener _: WalletBalanceSubscriptionListener
    ) {}

    func subscribeNetworkManagementBalance(wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func unsubscribe(listener _: WalletBalanceSubscriptionListener) {}
}

private final class BackupRecoveryInteractor: BackupWalletInteractorInput {
    var appearances = 0
    func setup(with _: BackupWalletInteractorOutput) {}
    func removeBackupFromGoogle() {}
    func viewDidAppear() {
        appearances += 1
    }
}

private final class BackupRecoveryView: UIViewController, BackupWalletViewInput {
    var starts = 0
    var stops = 0
    func didReceive(viewModel _: ProfileViewModelProtocol) {}
    func didStartLoading() {
        starts += 1
    }

    func didStopLoading() {
        stops += 1
    }
}

private final class BackupRecoveryViewModelFactory: BackupWalletViewModelFactoryProtocol {
    func createViewModel(
        from wallet: fearless.MetaAccountModel, locale _: Locale, balance _: WalletBalanceInfo?,
        exportOptions _: [ExportOption], backupAccounts _: [OpenBackupAccount]?
    ) -> ProfileViewModelProtocol {
        ProfileViewModel(
            profileUserViewModel: WalletsManagmentCellViewModel(
                isSelected: false, walletName: wallet.name, fiatBalance: nil,
                dayChange: nil, accountScoreViewModel: nil
            ),
            profileOptionViewModel: [],
            logoutViewModel: ProfileOptionViewModel(
                title: "Logout", icon: nil, accessoryTitle: nil, accessoryImage: nil,
                accessoryType: .arrow, option: nil
            )
        )
    }
}

private final class BackupRecoveryRouter: BackupWalletRouterInput {
    var sheets: [SheetAlertPresentableViewModel] = []
    var mnemonicExports = 0
    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheets.append(viewModel)
    }

    func showMnemonicExport(flow _: ExportFlow, from _: ControllerBackedProtocol?) {
        mnemonicExports += 1
    }

    func showKeystoreExport(flow _: ExportFlow, from _: ControllerBackedProtocol?) {}
    func showSeedExport(flow _: ExportFlow, from _: ControllerBackedProtocol?) {}
    func showCreatePassword(
        wallet _: MetaAccountModel, accounts _: [fearless.ChainAccountInfo], options _: [ExportOption],
        from _: ControllerBackedProtocol?, moduleOutput _: BackupCreatePasswordModuleOutput?
    ) {}
    func showWalletDetails(wallet _: MetaAccountModel, from _: ControllerBackedProtocol?) {}
}

private final class BackupLookupOutput: BackupWalletInteractorOutput {
    let completed = XCTestExpectation(description: "Backup lookup completed")
    var failure: Error?
    var accounts: [OpenBackupAccount]?
    var wasMainThread = false
    func didReceiveBalances(result _: WalletBalancesResult) {}
    func didReceive(chains _: [ChainModel]) {}
    func didReceive(options _: [ExportOption]) {}
    func didReceive(error _: Error) {}
    func didReceiveBackupAccounts(result: Result<[OpenBackupAccount], Error>) {
        wasMainThread = Thread.isMainThread
        switch result {
        case let .success(accounts): self.accounts = accounts
        case let .failure(error): failure = error
        }
        completed.fulfill()
    }

    func didReceiveRemove(result: Result<Void, Error>) {
        wasMainThread = Thread.isMainThread
        if case let .failure(error) = result {
            failure = error
        }
        completed.fulfill()
    }
}

private final class BackupLookupCloud: CloudStorageServiceProtocol {
    var isUserAuthorized = false
    var lookups = 0
    var disconnects = 0
    func signInIfNeeded() async throws -> CloudStorageAccountState {
        .authorized
    }

    func getBackupAccounts() async throws -> [OpenBackupAccount] {
        lookups += 1; return []
    }

    func saveBackup(account _: OpenBackupAccount, password _: String) async throws {}
    func saveBackupAndImport(account: OpenBackupAccount, password _: String) async throws -> OpenBackupAccount {
        account
    }

    func importBackup(account: OpenBackupAccount, password _: String) async throws -> OpenBackupAccount {
        account
    }

    func deleteBackup(account _: OpenBackupAccount) async throws {}
    func disconnect() {
        disconnects += 1
    }
}

private final class BackupLookupRepository: DataProviderRepositoryProtocol {
    typealias Model = ChainModel
    func fetchOperation(
        by _: @escaping () throws -> [String],
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(
        by _: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<Model?> {
        ClosureOperation { nil }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func saveOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func saveBatchOperation(
        _: @escaping () throws -> [Model],
        _: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func replaceOperation(_: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { 0 }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { () }
    }
}
