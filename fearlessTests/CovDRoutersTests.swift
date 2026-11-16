import Foundation
import RobinHood
import SoraFoundation
import SSFModels
import SSFPolkaswap
import SSFPools
import SSFUtils
import UIKit
import XCTest

@testable import fearless

final class CovDHostController: UIViewController, ControllerBackedProtocol {}

final class CovDRouteOutputSpy: PolkaswapTransaktionSettingsModuleOutput, SelectAssetModuleOutput {
    private(set) var markets: [LiquiditySourceType] = []
    private(set) var assets: [String?] = []

    func didReceive(market: LiquiditySourceType, slippadgeTolerance _: Float) { markets.append(market) }
    func assetSelection(didCompleteWith chainAsset: ChainAsset?, contextTag _: Int?) { assets.append(chainAsset?.asset.symbol) }
}

final class CovDRoutersTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    /// Hosts a fresh navigation stack in the test window and returns it with its root.
    private func freshStack() throws -> (UINavigationController, CovDHostController) {
        let root = CovDHostController()
        let navigation = UINavigationController(rootViewController: root)
        if let window {
            window.rootViewController?.dismiss(animated: false)
            window.rootViewController = navigation
            window.layoutIfNeeded()
        } else {
            window = try CovDFixtures.host(navigation)
        }
        return (navigation, root)
    }

    private func presented(by controller: UIViewController) -> UIViewController? {
        CovDFixtures.spin { controller.presentedViewController != nil }
        return controller.presentedViewController
    }

    func testLiquidityRoutersPushTheNextScreensForSora() throws {
        let chain = CovDLiquidityFixtures.chain(chainId: PolkamarktConstants.soraChainId)
        let wallet = CovDFixtures.wallet()
        let pair = CovDLiquidityFixtures.pair(chain)
        let assetPair = AssetIdPair(baseAssetIdCode: pair.baseAssetId, targetAssetIdCode: pair.targetAssetId)
        let removal = try CovDPoolHarness().removal

        var (navigation, root) = try freshStack()
        LiquidityPoolsListRouter().showPoolDetails(
            assetIdPair: assetPair, chain: chain, wallet: wallet, input: .initial, didSubmitTransactionClosure: { _ in }, from: root
        )
        XCTAssertTrue(navigation.topViewController is LiquidityPoolDetailsViewController)

        (navigation, root) = try freshStack()
        LiquidityPoolDetailsRouter().showSupplyFlow(
            liquidityPair: pair, chain: chain, wallet: wallet, availablePairs: [pair], didSubmitTransactionClosure: { _ in }, from: root
        )
        XCTAssertTrue(navigation.topViewController is LiquidityPoolSupplyViewController)

        (navigation, root) = try freshStack()
        LiquidityPoolDetailsRouter().showRemoveFlow(
            liquidityPair: pair, chain: chain, wallet: wallet, didSubmitTransactionClosure: { _ in }, from: root
        )
        XCTAssertTrue(navigation.topViewController is LiquidityPoolRemoveLiquidityViewController)

        (navigation, root) = try freshStack()
        LiquidityPoolSupplyRouter().showConfirmation(
            chain: chain, wallet: wallet, liquidityPair: pair,
            inputData: LiquidityPoolSupplyConfirmInputData(baseAssetAmount: 1, targetAssetAmount: 2, slippageTolerance: 0.5, availablePools: [pair]),
            didSubmitTransactionClosure: { _ in }, from: root
        )
        XCTAssertTrue(navigation.topViewController is LiquidityPoolSupplyConfirmViewController)

        (navigation, root) = try freshStack()
        LiquidityPoolRemoveLiquidityRouter().showConfirmation(
            chain: chain, wallet: wallet, liquidityPair: pair, info: removal, didSubmitTransactionClosure: { _ in }, from: root
        )
        XCTAssertTrue(navigation.topViewController is LiquidityPoolRemoveLiquidityConfirmViewController)

        (navigation, root) = try freshStack()
        LiquidityPoolsOverviewRouter().showAllAvailablePools(chain: chain, wallet: wallet, from: root, moduleOutput: nil)
        XCTAssertTrue(navigation.topViewController is LiquidityPoolsListViewController)

        (navigation, root) = try freshStack()
        LiquidityPoolsOverviewRouter().showAllUserPools(chain: chain, wallet: wallet, from: root, moduleOutput: nil)
        XCTAssertTrue(navigation.topViewController is LiquidityPoolsListViewController)
    }

    func testLiquidityRoutersStayPutWhenTheChainCannotHostTheFlow() throws {
        let fixture = try CovDPoolHarness()
        let wallet = CovDFixtures.wallet()
        let (navigation, root) = try freshStack()
        LiquidityPoolDetailsRouter().showSupplyFlow(
            liquidityPair: fixture.pair, chain: fixture.chain, wallet: wallet, availablePairs: nil,
            didSubmitTransactionClosure: { _ in }, from: root
        )
        LiquidityPoolDetailsRouter().showRemoveFlow(
            liquidityPair: fixture.pair, chain: fixture.chain, wallet: wallet, didSubmitTransactionClosure: { _ in }, from: root
        )
        LiquidityPoolSupplyRouter().showConfirmation(
            chain: fixture.chain, wallet: wallet, liquidityPair: fixture.pair,
            inputData: LiquidityPoolSupplyConfirmInputData(baseAssetAmount: 1, targetAssetAmount: 2, slippageTolerance: 0.5, availablePools: nil),
            didSubmitTransactionClosure: { _ in }, from: root
        )
        LiquidityPoolRemoveLiquidityRouter().showConfirmation(
            chain: fixture.chain, wallet: wallet, liquidityPair: fixture.pair, info: fixture.removal,
            didSubmitTransactionClosure: { _ in }, from: root
        )
        XCTAssertEqual(navigation.viewControllers, [root])
        XCTAssertNil(root.presentedViewController)
    }

    func testCompletionRoutersReturnToTheRootAndPresentAllDone() throws {
        let chain = CovDLiquidityFixtures.chain(chainId: PolkamarktConstants.soraChainId)
        let xor = CovDLiquidityFixtures.chainAsset(chain, CovDLiquidityFixtures.xor)
        let completions: [(ControllerBackedProtocol) -> Void] = [
            { LiquidityPoolSupplyConfirmRouter().complete(on: $0, title: "0xsupply", chainAsset: xor) },
            { LiquidityPoolRemoveLiquidityRouter().complete(on: $0, title: "0xremove", chainAsset: xor) }
        ]
        for complete in completions {
            let (navigation, root) = try freshStack()
            let pushed = CovDHostController()
            navigation.pushViewController(pushed, animated: false)
            complete(pushed)
            XCTAssertTrue(CovDFixtures.spin { navigation.viewControllers == [root] })
            let done = try XCTUnwrap(presented(by: navigation))
            XCTAssertTrue(done is AllDoneViewController)
            XCTAssertEqual(done.modalPresentationStyle, .custom)
        }

        let (navigation, root) = try freshStack()
        let confirmation = CovDHostController()
        navigation.pushViewController(confirmation, animated: false)
        var completed = 0
        PolkaswapSwapConfirmationRouter().complete(
            on: confirmation, hashString: "0xswap", chainAsset: xor, completeClosure: { completed += 1 }
        )
        let swapDone = try XCTUnwrap(presented(by: confirmation))
        XCTAssertTrue(swapDone is AllDoneViewController)
        XCTAssertEqual(swapDone.modalPresentationStyle, .custom)
        XCTAssertEqual(completed, 0)
        // Closing the result runs the completion and leaves the confirmation screen.
        swapDone.dismiss(animated: false)
        XCTAssertTrue(CovDFixtures.spin { completed == 1 })
        XCTAssertTrue(CovDFixtures.spin { navigation.viewControllers == [root] })
    }

    func testPolkaswapRoutersPresentSettingsAssetPickersAndDisclaimer() throws {
        let output = CovDRouteOutputSpy()
        let wallet = CovDFixtures.wallet()
        let chain = CovDSwapFixtures.chain()
        let router = PolkaswapAdjustmentRouter()

        var (_, root) = try freshStack()
        router.showSelectMarket(from: root, markets: [.smart, .xyk, .tbc], selectedMarket: .xyk, slippadgeTolerance: 0.5, moduleOutput: output)
        XCTAssertTrue(presented(by: root) is PolkaswapTransaktionSettingsViewController)

        (_, root) = try freshStack()
        router.showSelectAsset(
            from: root, wallet: wallet, chainAssets: chain.chainAssets, selectedAssetId: nil, contextTag: 1, output: output
        )
        XCTAssertTrue(presented(by: root) is SelectAssetViewController)

        (_, root) = try freshStack()
        router.showDisclaimer(moduleOutput: nil, from: root)
        XCTAssertTrue(presented(by: root) is PolkaswapDisclaimerViewController)

        (_, root) = try freshStack()
        PolkaswapTransaktionSettingsRouter().showSelectMarket(from: root, markets: [.smart, .tbc], moduleOutput: nil)
        XCTAssertTrue(presented(by: root) is SelectMarketViewController)

        (_, root) = try freshStack()
        LiquidityPoolSupplyRouter().showSelectAsset(
            from: root, wallet: wallet, chainAssets: chain.chainAssets, selectedAssetId: "xor", contextTag: 0, output: output
        )
        XCTAssertTrue(presented(by: root) is SelectAssetViewController)
        XCTAssertTrue(output.markets.isEmpty)
        XCTAssertTrue(output.assets.isEmpty)
    }

    func testSwapConfirmationIsPushedWithoutTheTabBar() throws {
        let (navigation, root) = try freshStack()
        let input = PolkaswapAdjustmentRouter().showConfirmation(
            with: CovDSwapFixtures.params(), from: root, completeClosure: nil
        )
        XCTAssertNotNil(input)
        let confirmation = try XCTUnwrap(navigation.topViewController as? PolkaswapSwapConfirmationViewController)
        XCTAssertTrue(confirmation.hidesBottomBarWhenPushed)
    }
}

final class CovDTabWireframeSpy: MainTabBarWireframeProtocol {
    private(set) var reloadedWallets: [String] = []
    private(set) var polkaswapReloads = 0
    private(set) var imports = 0

    func reloadWalletDependentViews(on _: MainTabBarViewProtocol?, wallet: MetaAccountModel) { reloadedWallets.append(wallet.metaId) }
    func reloadPolkaswapViewIfUnavailable(on _: MainTabBarViewProtocol?, wallet _: MetaAccountModel) { polkaswapReloads += 1 }
    func presentAccountImport(on _: MainTabBarViewProtocol?) { imports += 1 }
}

final class CovDTabInteractorSpy: MainTabBarInteractorInputProtocol {
    private(set) weak var output: MainTabBarInteractorOutputProtocol?
    func setup(with output: MainTabBarInteractorOutputProtocol) { self.output = output }
}

final class CovDNetworkStatusSpy: NetworkAvailabilityLayerInteractorOutputProtocol {
    private(set) var states: [Bool] = []
    func didDecideUnreachableStatusPresentation() { states.append(false) }
    func didDecideReachableStatusPresentation() { states.append(true) }
}

final class CovDReachabilitySpy: ReachabilityManagerProtocol {
    var isReachable = true
    private(set) var listeners = 0
    func add(listener _: ReachabilityListenerDelegate) throws { listeners += 1 }
    func remove(listener _: ReachabilityListenerDelegate) {}
}

final class CovDTabViewRecorder: UIViewController, MainTabBarViewProtocol {
    var isPolkaswapUnavailable = false
    private(set) var markets: [String] = []
    func didReplaceView(for _: UIViewController, for _: Int) {}
    func openPolkamarkt(marketId: String) { markets.append(marketId) }
}

final class CovDTabBarRecorder: UITabBarController, MainTabBarViewProtocol {
    var isPolkaswapUnavailable = false
    func didReplaceView(for _: UIViewController, for _: Int) {}
    func openPolkamarkt(marketId _: String) {}
}

final class CovDOnboardingStub: UIViewController, OnboardingMainViewProtocol {
    func didReceive(preinstalledWalletEnabled _: Bool) {}
}

final class CovDStatusWindowSpy: ApplicationStatusPresentable {
    func presentStatus(with _: ApplicationStatusAlertEvent, animated _: Bool) {}
    func dismissStatus(with _: ApplicationStatusAlertEvent?, animated _: Bool) {}
}

final class CovDTabPresenterSpy: MainTabBarPresenterProtocol {
    private(set) var loads = 0
    func didLoad(view _: MainTabBarViewProtocol) { loads += 1 }
}

final class CovDMainTabBarTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    func testPresenterForwardsInteractorEventsAndReachability() {
        let wireframe = CovDTabWireframeSpy()
        let interactor = CovDTabInteractorSpy()
        let status = CovDNetworkStatusSpy()
        let reachability = CovDReachabilitySpy()
        let wallet = CovDFixtures.wallet()
        let handler = ApplicationHandler()
        let presenter = MainTabBarPresenter(
            wireframe: wireframe,
            interactor: interactor,
            appVersionObserver: AppVersionObserver(
                operationManager: OperationManager(), currentAppVersion: nil, wireframe: wireframe, locale: Locale(identifier: "en")
            ),
            applicationHandler: handler,
            networkStatusPresenter: status,
            reachability: nil,
            walletConnectCoordinator: WalletConnectCoordinator(),
            wallet: wallet,
            localizationManager: LocalizationManager.shared
        )
        XCTAssertTrue(handler.delegate === presenter)
        let view = CovDTabViewRecorder()
        presenter.didLoad(view: view)
        XCTAssertTrue(interactor.output === presenter)

        presenter.didPrepareChains()
        XCTAssertEqual(wireframe.polkaswapReloads, 1)
        let other = CovDFixtures.wallet()
        presenter.didChangeSelectedAccount(other)
        XCTAssertEqual(wireframe.reloadedWallets, [other.metaId])
        presenter.didRequestImportAccount()
        XCTAssertEqual(wireframe.imports, 1)
        presenter.didRequestPolkamarkt(marketId: "9")
        XCTAssertEqual(view.markets, ["9"])
        presenter.didReceiveWillEnterForeground(notification: Notification(name: UIApplication.willEnterForegroundNotification))
        presenter.applyLocalization()

        presenter.didChangeReachability(by: reachability)
        reachability.isReachable = false
        presenter.didChangeReachability(by: reachability)
        XCTAssertEqual(status.states, [true, false])
    }

    private func dependencies(
        wallet: MetaAccountModel?,
        importer: KeystoreImportServiceProtocol?
    ) -> MainTabBarViewFactory.Dependencies {
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        settings.internalValue = wallet
        return MainTabBarViewFactory.Dependencies(
            walletSettings: settings,
            localizationManager: LocalizationManager.shared,
            walletConnectService: WalletConnectServiceImpl.shared,
            reachability: nil,
            eventCenter: CovDTabEventSpy(),
            operationManager: OperationManager(),
            serviceCoordinatorBuilder: { _, _ in CovDTabServiceSpy() },
            keystoreImportServiceProvider: { importer },
            applicationHandlerBuilder: { ApplicationHandler() }
        )
    }

    func testFactoryBuildsTheTabBarFromInjectedDependencies() throws {
        let wallet = CovDFixtures.wallet(substrate: false)
        let view = MainTabBarViewFactory.createView(
            presentingWindow: CovDStatusWindowSpy(),
            dependencies: dependencies(wallet: wallet, importer: CovDTabImportSpy())
        )
        let controller = try XCTUnwrap(view?.controller as? MainTabBarViewController)
        XCTAssertEqual(MainTabBarDestination.allCases.compactMap { controller.controller(for: $0) }.count, 5)
        XCTAssertTrue((controller.controller(for: .defi) as? UINavigationController)?.viewControllers.first is DeFiHubViewController)
        XCTAssertTrue(controller.isPolkaswapUnavailable)

        XCTAssertNil(MainTabBarViewFactory.createView(
            presentingWindow: CovDStatusWindowSpy(), dependencies: dependencies(wallet: nil, importer: CovDTabImportSpy())
        ))
        XCTAssertNil(MainTabBarViewFactory.createView(
            presentingWindow: CovDStatusWindowSpy(), dependencies: dependencies(wallet: wallet, importer: nil)
        ))

        let live = MainTabBarViewFactory.Dependencies.live
        XCTAssertTrue(live.walletSettings === SelectedWalletSettings.shared)
        XCTAssertTrue(live.eventCenter as AnyObject === EventCenter.shared as AnyObject)
        XCTAssertNotNil(live.applicationHandlerBuilder())
    }

    func testWireframePresentsImportOnceAndNotOverAnExistingImport() throws {
        let tabs = CovDTabViewRecorder()
        window = try CovDFixtures.host(tabs)
        let wireframe = MainTabBarWireframe()
        wireframe.presentAccountImport(on: nil)
        XCTAssertNil(tabs.presentedViewController)

        // The import screen needs the registered keystore import service; without it nothing is shown.
        let importAvailable = AccountImportViewFactory.createViewForAdding(defaultSource: .mnemonic) != nil
        wireframe.presentAccountImport(on: tabs)
        guard importAvailable else {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
            XCTAssertNil(tabs.presentedViewController)
            return
        }
        CovDFixtures.spin { tabs.presentedViewController != nil }
        let importStack = try XCTUnwrap(tabs.presentedViewController as? UINavigationController)
        XCTAssertTrue(importStack.viewControllers.first is AccountImportViewProtocol)
        wireframe.presentAccountImport(on: tabs)
        XCTAssertTrue(tabs.presentedViewController === importStack)
        XCTAssertNil(importStack.presentedViewController)
    }

    func testWireframeRecognisesImportsInsideTabControllers() throws {
        let tabBar = CovDTabBarRecorder()
        tabBar.viewControllers = [UINavigationController(rootViewController: CovDOnboardingStub())]
        window = try CovDFixtures.host(tabBar)
        MainTabBarWireframe().presentAccountImport(on: tabBar)
        XCTAssertNil(tabBar.presentedViewController)

        let destinations: [UIViewController] = MainTabBarDestination.allCases.map {
            UINavigationController(rootViewController: $0 == .portfolio ? CovDOnboardingStub() : UIViewController())
        }
        let mainTabBar = MainTabBarViewController(
            viewControllers: destinations, presenter: CovDTabPresenterSpy(),
            localizationManager: LocalizationManager.shared, idiom: .phone
        )
        window?.rootViewController = mainTabBar
        window?.layoutIfNeeded()
        XCTAssertEqual(mainTabBar.selectedDestination, .portfolio)
        MainTabBarWireframe().presentAccountImport(on: mainTabBar)
        XCTAssertNil(mainTabBar.presentedViewController)

        // An import shown modally over a plain navigation stack also counts.
        let host = CovDTabViewRecorder()
        window?.rootViewController = host
        host.present(UINavigationController(rootViewController: CovDOnboardingStub()), animated: false)
        let modal = host.presentedViewController
        MainTabBarWireframe().presentAccountImport(on: host)
        XCTAssertTrue(host.presentedViewController === modal)
        XCTAssertNil(modal?.presentedViewController)
    }

    func testTabBarReturnsToRootOnReselectAndOpensPolkamarktInDeFi() throws {
        let wallet = CovDFixtures.wallet()
        let destinations: [UIViewController] = MainTabBarDestination.allCases.map { destination in
            let root: UIViewController = destination == .defi ? DeFiHubViewController(wallet: wallet) : UIViewController()
            let navigation = UINavigationController(rootViewController: root)
            navigation.tabBarItem = MainTabBarViewFactory.createTabBarItem(for: destination)
            return navigation
        }
        let presenter = CovDTabPresenterSpy()
        let controller = MainTabBarViewController(
            viewControllers: destinations, presenter: presenter, localizationManager: LocalizationManager.shared, idiom: .phone
        )
        window = try CovDFixtures.host(controller)
        XCTAssertTrue(CovDFixtures.spin { presenter.loads == 1 })
        let selected = try XCTUnwrap(controller.viewControllers?[controller.selectedIndex] as? UINavigationController)
        selected.pushViewController(UIViewController(), animated: false)
        XCTAssertEqual(selected.viewControllers.count, 2)
        XCTAssertTrue(controller.tabBarController(controller, shouldSelect: selected))
        XCTAssertTrue(CovDFixtures.spin { selected.viewControllers.count == 1 })

        controller.openPolkamarkt(marketId: "12")
        XCTAssertEqual(controller.selectedIndex, MainTabBarDestination.defi.rawValue)
        let defi = try XCTUnwrap(controller.viewControllers?[MainTabBarDestination.defi.rawValue] as? UINavigationController)
        XCTAssertTrue(defi.viewControllers.first is DeFiHubViewController)
    }
}
