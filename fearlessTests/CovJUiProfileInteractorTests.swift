import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFModels
@testable import fearless

final class CovJUiProfileOutput: ProfileInteractorOutputProtocol {
    private(set) var wallets: [MetaAccountModel] = []
    private(set) var errors: [Error] = []
    private(set) var currencies: [Currency] = []
    private(set) var balanceResults: [Result<[MetaAccountId: WalletBalanceInfo], Error>] = []
    private(set) var issues: [[ChainIssue]] = []

    func didReceive(wallet: MetaAccountModel) { wallets.append(wallet) }
    func didReceiveUserDataProvider(error: Error) { errors.append(error) }
    func didRecieve(selectedCurrency: Currency) { currencies.append(selectedCurrency) }
    func didReceiveWalletBalances(_ balances: Result<[MetaAccountId: WalletBalanceInfo], Error>) { balanceResults.append(balances) }
    func didReceiveMissingAccount(issues: [ChainIssue]) { self.issues.append(issues) }
}

final class CovJUiBalanceAdapter: WalletBalanceSubscriptionAdapterProtocol {
    private(set) var walletIds: [String] = []
    private(set) weak var listener: WalletBalanceSubscriptionListener?

    func subscribeWalletBalance(wallet: MetaAccountModel, listener: WalletBalanceSubscriptionListener) {
        walletIds.append(wallet.metaId)
        self.listener = listener
    }

    func subscribeWalletsBalances(listener _: WalletBalanceSubscriptionListener) {}
    func subscribeChainAssetBalance(wallet _: MetaAccountModel, chainAsset _: ChainAsset, listener _: WalletBalanceSubscriptionListener) {}
    func subscribeChainAssetsBalance(chainAssets _: [ChainAsset], wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func subscribeNetworkManagementBalance(wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func unsubscribe(listener _: WalletBalanceSubscriptionListener) {}
}

final class CovJUiIssuesCenter: ChainsIssuesCenterProtocol {
    private(set) weak var listener: ChainsIssuesCenterListener?
    private(set) var getExistingFlags: [Bool] = []

    func addIssuesListener(_ listener: ChainsIssuesCenterListener, getExisting: Bool) {
        self.listener = listener
        getExistingFlags.append(getExisting)
    }

    func removeIssuesListener(_: ChainsIssuesCenterListener) {}
    func forceNotify() {}
}

/// Called from the logout operation's completion block, so the count is lock-protected.
final class CovJUiDisconnect: WalletConnectDisconnectService {
    private let lock = NSLock()
    private var count = 0

    var disconnectAllCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func disconnect(wallet _: MetaAccountModel) async throws {}

    func disconnectAllSessions() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

final class CovJUiProfileInteractorFixture {
    let wallet: MetaAccountModel
    let settings: SelectedWalletSettings
    let managed: CovJMemoryRepository<fearless.ManagedMetaAccountModel>
    let adapter: CovJUiBalanceAdapter
    let issues: CovJUiIssuesCenter
    let disconnect: CovJUiDisconnect
    let keychain: InMemoryKeychain
    let output: CovJUiProfileOutput
    let interactor: ProfileInteractor

    init() {
        let wallet = AccountGenerator.generateMetaAccount()
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        let managed = CovJMemoryRepository<fearless.ManagedMetaAccountModel>([fearless.ManagedMetaAccountModel(info: wallet, isSelected: true)])
        let adapter = CovJUiBalanceAdapter()
        let issues = CovJUiIssuesCenter()
        let disconnect = CovJUiDisconnect()
        let keychain = InMemoryKeychain()
        self.wallet = wallet
        self.settings = settings
        self.managed = managed
        self.adapter = adapter
        self.issues = issues
        self.disconnect = disconnect
        self.keychain = keychain
        output = CovJUiProfileOutput()
        interactor = ProfileInteractor(
            selectedWalletSettings: settings,
            eventCenter: EventCenter(),
            repository: AnyDataProviderRepository(managed),
            operationQueue: OperationQueue(),
            selectedMetaAccount: wallet,
            walletBalanceSubscriptionAdapter: adapter,
            walletRepository: AnyDataProviderRepository(CovJMemoryRepository<MetaAccountModel>([wallet])),
            chainsIssuesCenter: issues,
            walletConnectDisconnectService: disconnect,
            secretEraser: WalletSecretEraser(keystore: keychain, storedTags: { [] })
        )
    }
}

// MARK: - Interactor

final class CovJUiProfileInteractorTests: XCTestCase {
    func testSetupWithoutSelectedWalletReportsErrorButProvidesCurrency() {
        let f = CovJUiProfileInteractorFixture()
        f.interactor.setup(with: f.output)

        XCTAssertEqual(f.output.errors.compactMap { $0 as? ProfileInteractorError }, [.noSelectedAccount])
        XCTAssertTrue(f.output.wallets.isEmpty)
        XCTAssertEqual(f.output.currencies.map(\.id), [f.wallet.selectedCurrency.id])
        XCTAssertEqual(f.adapter.walletIds, [f.wallet.metaId])
        XCTAssertTrue(f.adapter.listener === f.interactor)
        XCTAssertEqual(f.issues.getExistingFlags, [true])
        XCTAssertTrue(f.issues.listener === f.interactor)
    }

    func testSelectedWalletReachesOutputAndRefreshesOnEvents() {
        let f = CovJUiProfileInteractorFixture()
        f.settings.internalValue = f.wallet
        f.interactor.setup(with: f.output)
        XCTAssertEqual(f.output.wallets.map(\.metaId), [f.wallet.metaId])
        XCTAssertTrue(f.output.errors.isEmpty)
        XCTAssertEqual(f.adapter.walletIds, [f.wallet.metaId, f.wallet.metaId])

        guard case let .wallet(listened) = f.interactor.type else {
            return XCTFail("Profile listens to one wallet")
        }
        XCTAssertEqual(listened.metaId, f.wallet.metaId)

        f.interactor.processSelectedAccountChanged(event: SelectedAccountChanged(account: f.wallet))
        f.interactor.processSelectedUsernameChanged(event: SelectedUsernameChanged())
        XCTAssertEqual(f.output.wallets.count, 3)

        f.interactor.processWalletNameChanged(event: WalletNameChanged(wallet: AccountGenerator.generateMetaAccount()))
        XCTAssertEqual(f.output.wallets.count, 3, "another wallet's name is ignored")
        f.interactor.processWalletNameChanged(event: WalletNameChanged(wallet: f.wallet.replacingName("Renamed elsewhere")))
        XCTAssertEqual(f.output.wallets.count, 4)
        XCTAssertEqual(f.output.wallets.last?.name, f.wallet.name, "the stored selection is re-read, not the event payload")
    }

    func testBalancesIssuesAndCurrencyUpdatesReachOutput() throws {
        let f = CovJUiProfileInteractorFixture()
        f.interactor.setup(with: f.output)

        f.interactor.handle(result: .success([f.wallet.metaId: CovJUiProfileFixture.balance(total: 3)]))
        f.interactor.handle(result: .failure(CovJError("balance")))
        XCTAssertEqual(f.output.balanceResults.count, 2)
        if case let .success(balances) = try XCTUnwrap(f.output.balanceResults.first) {
            XCTAssertEqual(balances[f.wallet.metaId]?.totalFiatValue, 3)
        } else {
            XCTFail("the first result is a success")
        }

        let listener = try XCTUnwrap(f.issues.listener)
        listener.handleChainsIssues([.network(chains: []), .missingAccount(chains: []), .missingAccount(chains: [])])
        let missing = try XCTUnwrap(f.output.issues.last)
        XCTAssertEqual(missing.count, 2)
        XCTAssertTrue(missing.allSatisfy { issue in
            if case .missingAccount = issue { return true }
            return false
        })

        f.interactor.update(currency: .euro())
        XCTAssertEqual(f.output.currencies.map(\.id), [f.wallet.selectedCurrency.id, "eur"])
    }

    func testUpdateWalletSavesOnlyTheShownWallet() {
        let f = CovJUiProfileInteractorFixture()
        f.interactor.setup(with: f.output)

        f.interactor.updateWallet(AccountGenerator.generateMetaAccount())
        XCTAssertNil(f.settings.value, "another wallet is not saved")

        f.interactor.updateWallet(f.wallet.replacingName("Renamed"))
        XCTAssertEqual(f.settings.value?.name, "Renamed")
        XCTAssertTrue(CovJWait.until { f.output.wallets.last?.name == "Renamed" })

        let settled = expectation(description: "the save settles")
        f.settings.performAfterPendingSaves { settled.fulfill() }
        wait(for: [settled], timeout: 5)
    }

    func testLogoutDeletesWalletsErasesTheirSecretsAndDisconnects() throws {
        let f = CovJUiProfileInteractorFixture()
        let walletTag = fearless.KeystoreTagV2.entropyTagForMetaId(f.wallet.metaId)
        try f.keychain.saveKey(Data([1, 2, 3]), with: walletTag)
        try f.keychain.saveKey(Data([4]), with: "unrelated-secret")

        let finished = expectation(description: "logout finished")
        f.interactor.logout { finished.fulfill() }
        wait(for: [finished], timeout: 5)

        XCTAssertTrue(f.managed.items.isEmpty)
        XCTAssertEqual(f.disconnect.disconnectAllCount, 1)
        XCTAssertFalse(try f.keychain.checkKey(for: walletTag))
        XCTAssertTrue(try f.keychain.checkKey(for: "unrelated-secret"))
    }

    func testFailedLogoutKeepsSecretsButStillDisconnects() throws {
        let f = CovJUiProfileInteractorFixture()
        let walletTag = fearless.KeystoreTagV2.entropyTagForMetaId(f.wallet.metaId)
        try f.keychain.saveKey(Data([1, 2, 3]), with: walletTag)
        f.managed.failure = CovJError("store")

        let finished = expectation(description: "logout finished")
        f.interactor.logout { finished.fulfill() }
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(f.disconnect.disconnectAllCount, 1)
        XCTAssertTrue(try f.keychain.checkKey(for: walletTag), "secrets stay when the rows could not be deleted")
        f.managed.failure = nil
        XCTAssertEqual(f.managed.items.map(\.identifier), [f.wallet.metaId])
    }
}

// MARK: - Wireframe (only routes whose modules start no networking)

final class CovJUiProfileWireframeTests: XCTestCase {
    private func settle(_ host: CovJHostedView) {
        _ = CovJWait.until { host.navigation.transitionCoordinator == nil }
    }

    func testCloseDismissesThePresentedController() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let modal = UIViewController()
        host.controller.present(modal, animated: false)
        XCTAssertTrue(CovJWait.until { host.presented === modal })

        ProfileWireframe().close(view: CovJUiControllerView(modal))
        XCTAssertTrue(CovJWait.until(timeout: 3) { host.presented == nil })
    }

    func testTonConnectWithoutTonAccountExplainsHowToAddOne() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        ProfileWireframe().showTonConnectCapability(from: host, hasTonAccount: false)

        XCTAssertTrue(CovJWait.until { host.presented is UIAlertController })
        let alert = try XCTUnwrap(host.presented as? UIAlertController)
        XCTAssertEqual(alert.title, "TonConnect")
        XCTAssertEqual(alert.message, "Select or restore your TON wallet in Wallets & Accounts to connect applications.")
        XCTAssertEqual(alert.actions.map(\.title), ["OK"])
        XCTAssertEqual(alert.actions.first?.style, .default)
    }

    func testLanguageAndAboutArePushedOnlyInsideANavigationStack() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let wireframe = ProfileWireframe()
        let view = CovJUiProfileView(controller: host.controller)

        wireframe.showLanguageSelection(from: view)
        XCTAssertTrue(host.top is LanguageSelectionViewController)
        XCTAssertEqual(host.top?.hidesBottomBarWhenPushed, true)
        settle(host)

        wireframe.showAbout(from: view)
        XCTAssertTrue(host.top is AboutViewController)
        XCTAssertEqual(host.top?.hidesBottomBarWhenPushed, true)
        settle(host)

        let detached = CovJUiProfileView()
        wireframe.showLanguageSelection(from: detached)
        wireframe.showAbout(from: detached)
        XCTAssertEqual(host.navigation.viewControllers.count, 3)
        XCTAssertNil(detached.controller.presentedViewController)
    }

    func testPolkaswapDisclaimerIsPresented() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        ProfileWireframe().showPolkaswapDisclaimer(from: host)
        XCTAssertTrue(CovJWait.until { host.presented is PolkaswapDisclaimerViewController })
    }
}
