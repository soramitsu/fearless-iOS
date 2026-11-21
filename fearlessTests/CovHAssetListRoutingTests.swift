import XCTest
import UIKit
import SSFModels
import SSFQRService
@testable import fearless

final class CovHWMCRouterHost: UIViewController, WalletMainContainerViewInput {
    private(set) var presented: [UIViewController] = []
    var busyWith: UIViewController?

    override var presentedViewController: UIViewController? { busyWith }

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presented.append(viewControllerToPresent)
        completion?()
    }

    func didReceiveViewModel(_: WalletMainContainerViewModel) {}
    func didReceiveNftAvailability(isNftAvailable _: Bool) {}
}

final class CovHWMCScanOutput: ScanQRModuleOutput {
    private(set) var scans = 0
    func didFinishWith(scanType _: QRMatcherType) { scans += 1 }
}

final class CovHWMCAssetOutput: SelectAssetModuleOutput {
    private(set) var selections = 0
    func assetSelection(didCompleteWith _: ChainAsset?, contextTag _: Int?) { selections += 1 }
}

final class CovHAssetListRoutingTests: XCTestCase {
    private var window: UIWindow?
    private let wallet = AccountGenerator.generateMetaAccount()

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func hostWalletScreen() -> (CovHWMCRouterHost, CovHAssetListNavigationSpy) {
        let host = CovHWMCRouterHost()
        let navigation = CovHAssetListNavigationSpy(rootViewController: host)
        window = CovHAssetListFixture.host(navigation)
        return (host, navigation)
    }

    private func hostPortfolio() -> (CovHAssetListPresentingHost, CovHAssetListNavigationSpy) {
        let host = CovHAssetListPresentingHost()
        let navigation = CovHAssetListNavigationSpy(rootViewController: host)
        window = CovHAssetListFixture.host(navigation)
        return (host, navigation)
    }

    func testWalletScreenPresentsItsModules() {
        let (host, navigation) = hostWalletScreen()
        let router = WalletMainContainerRouter()
        let asset = CovHAssetListFixture.chainAsset()

        router.showWalletManagment(from: host, moduleOutput: nil)
        XCTAssertEqual(host.presented.count, 1, "wallet list")
        router.showScanQr(from: host, moduleOutput: CovHWMCScanOutput())
        XCTAssertEqual(host.presented.count, 2, "scanner")
        XCTAssertTrue(host.presented.last is FearlessNavigationController)
        router.showSearch(from: host, wallet: wallet)
        XCTAssertEqual(host.presented.count, 3, "search")
        XCTAssertEqual(host.presented.last?.modalPresentationStyle, .fullScreen)
        router.showSelectNetwork(from: host, wallet: wallet, delegate: nil)
        XCTAssertEqual(host.presented.count, 4, "networks")
        router.showSendFlow(from: host, wallet: wallet, initialData: .chainAsset(asset))
        XCTAssertEqual(host.presented.count, 5, "send")
        router.showWalletDetails(from: host, wallet: wallet)
        XCTAssertEqual(host.presented.count, 6, "wallet details")
        router.showAssetPicker(from: host, wallet: wallet, action: .receive, output: CovHWMCAssetOutput())
        XCTAssertEqual(host.presented.count, 7, "asset picker")
        router.showReceive(from: host, wallet: wallet, chainAsset: asset)
        XCTAssertEqual(host.presented.count, 8, "receive")

        router.showSelectCurrency(from: host, wallet: wallet)
        XCTAssertEqual(navigation.presentedControllers.count, 1, "currency is shown over the navigation stack")
    }

    func testFlowsNeedingATabBarOrAConnectionStayClosed() {
        let (host, navigation) = hostWalletScreen()
        let router = WalletMainContainerRouter()
        let asset = CovHAssetListFixture.chainAsset()

        router.showControllerAccountFlow(from: host, chainAsset: asset, wallet: wallet)
        router.showMainStaking(from: host)
        router.showSwap(from: host)

        XCTAssertTrue(host.presented.isEmpty)
        XCTAssertTrue(navigation.pushed.isEmpty)
        XCTAssertTrue(navigation.topViewController === host)
    }

    func testBusyWalletScreenDoesNotStackAnotherSheet() {
        let (host, _) = hostWalletScreen()
        host.busyWith = UIViewController()
        let router = WalletMainContainerRouter()

        router.showReceive(from: host, wallet: wallet, chainAsset: CovHAssetListFixture.chainAsset())
        XCTAssertTrue(host.presented.isEmpty, "Receive waits while another sheet is up")

        // Wallet details are presented directly, without the busy-sheet check.
        router.showWalletDetails(from: host, wallet: wallet)
        XCTAssertEqual(host.presented.count, 1)
        XCTAssertTrue(host.presented.first is FearlessNavigationController)
    }

    func testPortfolioPresentsItsModules() {
        let (host, _) = hostPortfolio()
        let router = ChainAssetListRouter()
        let asset = CovHAssetListFixture.chainAsset()
        let unique = UniqueChainModel(meta: wallet, chain: asset.chain)

        router.showSendFlow(from: host, chainAsset: asset, wallet: wallet)
        XCTAssertEqual(host.presented.count, 1, "send")
        XCTAssertTrue(host.presented.last is FearlessNavigationController)
        router.showReceiveFlow(from: host, chainAsset: asset, wallet: wallet)
        XCTAssertEqual(host.presented.count, 2, "receive")
        router.presentAccountOptions(from: host, locale: Locale(identifier: "en"), actions: [])
        XCTAssertEqual(host.presented.count, 3, "account options")
        router.showCreate(uniqueChainModel: unique, from: host)
        XCTAssertEqual(host.presented.count, 4, "create account")
        // Importing needs the keystore import service the app registers at launch.
        let importService: KeystoreImportServiceProtocol? = URLHandlingService.shared.findService()
        router.showImport(uniqueChainModel: unique, from: host)
        let afterImport = importService == nil ? 4 : 5
        XCTAssertEqual(host.presented.count, afterImport, "import account")
        router.showManageAsset(from: host, wallet: wallet, filter: .all, visibilityFilter: .hidden)
        XCTAssertEqual(host.presented.count, afterImport + 1, "manage assets")
        router.showIssueNotification(from: host, issues: [.network(chains: [asset.chain])], wallet: wallet)
        XCTAssertEqual(host.presented.count, afterImport + 2, "network issues")
        router.showWalletManagment(from: host)
        XCTAssertEqual(host.presented.count, afterImport + 3, "wallet list")
    }

    func testAssembliesBuildTheWalletScreenAndItsPortfolio() throws {
        let portfolio = try XCTUnwrap(ChainAssetListAssembly.configureModule(wallet: wallet, keyboardAdoptable: true))
        XCTAssertTrue(portfolio.view.controller is ChainAssetListViewController)
        XCTAssertTrue(portfolio.input is ChainAssetListPresenter)

        let home = try XCTUnwrap(WalletMainContainerAssembly.configureModule(wallet: wallet, walletConnect: CovHWMCWalletConnectStub()))
        XCTAssertTrue(home.view.controller is WalletMainContainerViewController)
        XCTAssertTrue(home.input is WalletMainContainerPresenter)
        XCTAssertFalse(home.view.controller.isViewLoaded)
    }
}
