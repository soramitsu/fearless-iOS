import XCTest
import UIKit
import IrohaCrypto
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFCloudStorage
import SSFModels
@testable import fearless

/// Lane-J backup fixtures: an English localization, wallets with fixed keys, balances and Google Drive backups.
enum CovJBkFixture {
    static let locale = Locale(identifier: "en")
    static var languages: [String]? { locale.rLanguages }
    static let phrase = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"

    static func localization() throws -> LocalizationManager {
        try XCTUnwrap(LocalizationManager(localization: "en"))
    }

    static func wallet(
        name: String = "Backup wallet",
        chainAccounts: Set<ChainAccountModel> = [],
        substrate: Bool = true
    ) -> MetaAccountModel {
        let substrateKey = Data((0 ..< 32).map { UInt8($0 + 1) })
        return MetaAccountModel(
            metaId: UUID().uuidString,
            name: name,
            substrateAccountId: substrate ? substrateKey : nil,
            substrateCryptoType: 0,
            substratePublicKey: substrate ? substrateKey : nil,
            ethereumAddress: Data((0 ..< 20).map { UInt8($0 + 40) }),
            ethereumPublicKey: Data((0 ..< 33).map { UInt8($0 + 80) }),
            chainAccounts: chainAccounts,
            assetKeysOrder: nil,
            canExportEthereumMnemonic: true,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: false,
            favouriteChainIds: []
        )
    }

    static func chainAccount(chainId: String, seed: UInt8) -> ChainAccountModel {
        ChainAccountModel(
            chainId: chainId,
            accountId: Data(repeating: seed, count: 32),
            publicKey: Data(repeating: seed, count: 32),
            cryptoType: 0,
            ethereumBased: false
        )
    }

    static func balance(
        for wallet: MetaAccountModel,
        total: Decimal = 1234.5,
        dayChangePercent: Decimal = 0.05,
        dayChangeValue: Decimal = -12,
        hiddenFiat: Decimal = 0
    ) -> WalletBalanceInfo {
        var exclusions = PortfolioExclusions()
        exclusions.hiddenFiat = hiddenFiat
        return WalletBalanceInfo(
            totalFiatValue: total, enabledAssetFiatBalance: total,
            dayChangePercent: dayChangePercent, dayChangeValue: dayChangeValue,
            totalDayChangePercent: dayChangePercent, totalDayChangeValue: dayChangeValue,
            currency: wallet.selectedCurrency, prices: [], accountInfos: [:], exclusions: exclusions, filteredPart: nil
        )
    }

    static func mnemonicRequest(username: String = "Created") throws -> MetaAccountImportMnemonicRequest {
        MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: phrase),
            username: username,
            substrateDerivationPath: "",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519,
            defaultChainId: nil
        )
    }

    static func profileViewModel(name: String = "Backup wallet", options: [String]) -> ProfileViewModel {
        ProfileViewModel(
            profileUserViewModel: WalletsManagmentCellViewModel(
                isSelected: false, walletName: name, fiatBalance: "$1.00", dayChange: nil, accountScoreViewModel: nil
            ),
            profileOptionViewModel: options.map {
                ProfileOptionViewModel(title: $0, icon: nil, accessoryTitle: nil, accessoryImage: nil, accessoryType: .arrow, option: nil)
            },
            logoutViewModel: ProfileOptionViewModel(
                title: "Logout", icon: nil, accessoryTitle: nil, accessoryImage: nil, accessoryType: .arrow, option: nil
            )
        )
    }
}

/// A presenter-facing view that counts loading calls; module views subclass it and add their inputs.
class CovJBkLoadableView {
    let controller = UIViewController()
    var isSetup: Bool { true }
    var loadableContentView: UIView { controller.view }
    var shouldDisableInteractionWhenLoading: Bool { false }
    private(set) var starts = 0
    private(set) var stops = 0

    func didStartLoading() { starts += 1 }
    func didStopLoading() { stops += 1 }
}

final class CovJBkStatisticsFetcher: AccountStatisticsFetching {
    func subscribeForStatistics(address _: String) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? { nil }
}

final class CovJBkEventCenter: EventCenterProtocol {
    private let lock = NSLock()
    private var recorded: [EventProtocol] = []

    var events: [EventProtocol] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func notify(with event: EventProtocol) {
        lock.lock()
        recorded.append(event)
        lock.unlock()
    }

    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}
    func remove(observer _: EventVisitorProtocol) {}
}

final class CovJBkSecretManager: SecretStoreManagerProtocol {
    var hasSecret = false
    private(set) var checked: [String] = []

    func loadSecret(
        for _: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (SecretDataRepresentable?) -> Void
    ) {
        completionQueue.async { completionBlock(nil) }
    }

    func saveSecret(
        _: SecretDataRepresentable,
        for _: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        completionQueue.async { completionBlock(false) }
    }

    func removeSecret(for _: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        completionQueue.async { completionBlock(false) }
    }

    func checkSecret(for _: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        let result = hasSecret
        completionQueue.async { completionBlock(result) }
    }

    func checkSecret(for identifier: String) -> Bool {
        checked.append(identifier)
        return hasSecret
    }
}

final class CovJBkRootAnimator: RootControllerAnimationCoordinatorProtocol {
    private(set) var controllers: [UIViewController] = []

    func animateTransition(to controller: UIViewController) { controllers.append(controller) }
    func animateTransition(to controller: UIViewController, in _: UIWindow) { controllers.append(controller) }
}

/// Google Drive stand-in: configurable answers, every call recorded in order. Never signs in or touches the network.
final class CovJBkCloudStorage: CloudStorageServiceProtocol {
    private let lock = NSLock()
    private var log: [String] = []
    private var savedAccounts: [OpenBackupAccount] = []

    var accountsResult: Result<[OpenBackupAccount], Error> = .success([])
    var importResult: Result<OpenBackupAccount, Error> = .failure(CloudStorageServiceError.notFound)
    var deleteError: Error?
    var saveError: Error?
    /// Changes what the upload reads back; nil reads back exactly what was written.
    var readback: ((OpenBackupAccount) -> OpenBackupAccount)?

    var calls: [String] {
        lock.lock()
        defer { lock.unlock() }
        return log
    }

    var saved: [OpenBackupAccount] {
        lock.lock()
        defer { lock.unlock() }
        return savedAccounts
    }

    private func record(_ call: String) {
        lock.lock()
        log.append(call)
        lock.unlock()
    }

    private func keep(_ account: OpenBackupAccount) {
        lock.lock()
        savedAccounts.append(account)
        lock.unlock()
    }

    var isUserAuthorized: Bool { true }

    func signInIfNeeded() async throws -> CloudStorageAccountState {
        record("signIn")
        return .authorized
    }

    func getBackupAccounts() async throws -> [OpenBackupAccount] {
        record("list")
        return try accountsResult.get()
    }

    func saveBackup(account _: OpenBackupAccount, password _: String) async throws {
        record("save")
    }

    func saveBackupAndImport(account: OpenBackupAccount, password: String) async throws -> OpenBackupAccount {
        record("saveAndImport:\(password)")
        keep(account)
        if let saveError { throw saveError }
        return readback?(account) ?? account
    }

    func importBackup(account: OpenBackupAccount, password: String) async throws -> OpenBackupAccount {
        record("import:\(account.address):\(password)")
        return try importResult.get()
    }

    func deleteBackup(account: OpenBackupAccount) async throws {
        record("delete:\(account.address)")
        if let deleteError { throw deleteError }
    }

    func disconnect() {
        record("disconnect")
    }
}

final class CovJBkBackupModelsTests: XCTestCase {
    func testBackupWalletOptionsMapEveryExportOption() {
        XCTAssertEqual(BackupWalletOptions(exportOptions: .mnemonic), .phrase)
        XCTAssertEqual(BackupWalletOptions(exportOptions: .seed), .seed)
        XCTAssertEqual(BackupWalletOptions(exportOptions: .keystore), .json)
        XCTAssertEqual(BackupWalletOptions.allCases, [.phrase, .seed, .json, .backupGoogle, .removeGoogle])
        XCTAssertEqual(BackupWalletOptions.removeGoogle.rawValue, 4)
    }

    func testCreatePasswordFlowExposesTheRequestOnlyWhenCreatingAWallet() throws {
        let request = try CovJBkFixture.mnemonicRequest(username: "Fresh")
        let create = BackupCreatePasswordFlow.createWallet(request)
        XCTAssertEqual(create.mnemonicRequest?.username, "Fresh")
        XCTAssertEqual(create.mnemonicRequest?.mnemonic.toString(), CovJBkFixture.phrase)

        let backup = BackupCreatePasswordFlow.backupWallet(
            flow: .multiple(wallet: CovJBkFixture.wallet(), accounts: []),
            options: [.mnemonic]
        )
        XCTAssertNil(backup.mnemonicRequest)
    }

    func testWalletNameScreenModeFollowsTheWallet() {
        guard case .create = WalletNameScreenMode(wallet: nil) else {
            return XCTFail("A missing wallet creates a new one")
        }
        let wallet = CovJBkFixture.wallet(name: "Renamed")
        guard case let .editing(edited) = WalletNameScreenMode(wallet: wallet) else {
            return XCTFail("A wallet is edited")
        }
        XCTAssertEqual(edited.metaId, wallet.metaId)
        XCTAssertEqual(edited.name, "Renamed")
    }

    func testFixtureWalletsAreBackedUpByTheirSubstrateAddress() {
        let wallet = CovJBkFixture.wallet()
        XCTAssertNil(GoogleDriveBackupContent.unsupportedReason(for: wallet))
        XCTAssertEqual(wallet.backupAddress, try wallet.substratePublicKey?.toAddress(using: .substrate(42)))

        let withoutSubstrate = CovJBkFixture.wallet(substrate: false)
        XCTAssertEqual(GoogleDriveBackupContent.unsupportedReason(for: withoutSubstrate), .walletWithoutSubstrateAccount)
        XCTAssertThrowsError(try GoogleDriveBackupContent(wallet: withoutSubstrate, accounts: [])) { error in
            XCTAssertEqual(error as? BackupCreatePasswordError, .walletWithoutSubstrateAccount)
        }
    }
}
