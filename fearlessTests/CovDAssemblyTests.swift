import Foundation
import SSFModels
import SSFPolkaswap
import SSFPools
import UIKit
import XCTest

@testable import fearless

final class CovDAssemblyTests: XCTestCase {
    func testLiquidityAssembliesCreateMatchingControllersAndInputs() throws {
        let chain = CovDLiquidityFixtures.chain(chainId: PolkamarktConstants.soraChainId)
        let wallet = CovDFixtures.wallet()
        let pair = CovDLiquidityFixtures.pair(chain)
        let assetPair = AssetIdPair(baseAssetIdCode: pair.baseAssetId, targetAssetIdCode: pair.targetAssetId)
        let supply = try XCTUnwrap(LiquidityPoolSupplyAssembly.configureModule(
            chain: chain, wallet: wallet, liquidityPair: pair, availablePairs: [pair], didSubmitTransactionClosure: { _ in }
        ))
        XCTAssertTrue(supply.view.controller is LiquidityPoolSupplyViewController)
        XCTAssertTrue(supply.input is LiquidityPoolSupplyPresenter)
        let removal = try XCTUnwrap(LiquidityPoolRemoveLiquidityAssembly.configureModule(
            wallet: wallet, chain: chain, liquidityPair: pair, didSubmitTransactionClosure: { _ in }
        ))
        XCTAssertTrue(removal.view.controller is LiquidityPoolRemoveLiquidityViewController)
        XCTAssertTrue(removal.input is LiquidityPoolRemoveLiquidityPresenter)
        let supplyConfirm = try XCTUnwrap(LiquidityPoolSupplyConfirmAssembly.configureModule(
            chain: chain, wallet: wallet, liquidityPair: pair,
            inputData: LiquidityPoolSupplyConfirmInputData(baseAssetAmount: 1, targetAssetAmount: 2, slippageTolerance: 0.5, availablePools: [pair]),
            didSubmitTransactionClosure: { _ in }
        ))
        XCTAssertTrue(supplyConfirm.view.controller is LiquidityPoolSupplyConfirmViewController)
        XCTAssertTrue(supplyConfirm.input is LiquidityPoolSupplyConfirmPresenter)
        let fixture = try CovDPoolHarness()
        let removeConfirm = try XCTUnwrap(LiquidityPoolRemoveLiquidityConfirmAssembly.configureModule(
            wallet: wallet, chain: chain, liquidityPair: pair, removeInfo: fixture.removal, didSubmitTransactionClosure: { _ in }
        ))
        XCTAssertTrue(removeConfirm.view.controller is LiquidityPoolRemoveLiquidityConfirmViewController)
        XCTAssertTrue(removeConfirm.input is LiquidityPoolRemoveLiquidityPresenter)
        let details = try XCTUnwrap(LiquidityPoolDetailsAssembly.configureModule(
            assetIdPair: assetPair, chain: chain, wallet: wallet, input: .initial, didSubmitTransactionClosure: { _ in }
        ))
        XCTAssertTrue(details.view.controller is LiquidityPoolDetailsViewController)
        XCTAssertTrue(details.input is LiquidityPoolDetailsPresenter)
        let user = try XCTUnwrap(LiquidityPoolsListAssembly.configureUserPoolsModule(
            chain: chain, wallet: wallet, moduleOutput: nil, type: .embed
        ))
        let available = try XCTUnwrap(LiquidityPoolsListAssembly.configureAvailablePoolsModule(
            chain: chain, wallet: wallet, moduleOutput: nil, type: .full
        ))
        XCTAssertTrue(user.view.controller is LiquidityPoolsListViewController)
        XCTAssertTrue(user.input is UserLiquidityPoolsListPresenter)
        XCTAssertTrue(available.view.controller is LiquidityPoolsListViewController)
        XCTAssertTrue(available.input is AvailableLiquidityPoolsListPresenter)
    }

    func testLiquidityAssembliesRejectUnsupportedChainsBeforeConstructingMutationScreens() throws {
        let fixture = try CovDPoolHarness()
        let wallet = CovDFixtures.wallet()
        XCTAssertNil(LiquidityPoolSupplyAssembly.configureModule(
            chain: fixture.chain, wallet: wallet, liquidityPair: fixture.pair, availablePairs: nil, didSubmitTransactionClosure: { _ in }
        ))
        XCTAssertNil(LiquidityPoolRemoveLiquidityAssembly.configureModule(
            wallet: wallet, chain: fixture.chain, liquidityPair: fixture.pair, didSubmitTransactionClosure: { _ in }
        ))
        XCTAssertNil(LiquidityPoolSupplyConfirmAssembly.configureModule(
            chain: fixture.chain, wallet: wallet, liquidityPair: fixture.pair,
            inputData: LiquidityPoolSupplyConfirmInputData(baseAssetAmount: 1, targetAssetAmount: 2, slippageTolerance: 0.5, availablePools: nil),
            didSubmitTransactionClosure: { _ in }
        ))
        XCTAssertNil(LiquidityPoolRemoveLiquidityConfirmAssembly.configureModule(
            wallet: wallet, chain: fixture.chain, liquidityPair: fixture.pair, removeInfo: fixture.removal, didSubmitTransactionClosure: { _ in }
        ))
        XCTAssertNil(LiquidityPoolsOverviewAssembly.configureModule(wallet: wallet, chainId: fixture.chain.chainId))
    }

    func testTabFactoriesKeepDestinationOrderTitlesAndUnavailableSwapState() throws {
        let wallet = CovDFixtures.wallet(substrate: false)
        let controllers = MainTabBarViewFactory.createViewControllers(walletConnect: WalletConnectServiceImpl.shared, wallet: wallet)
        XCTAssertEqual(controllers.count, MainTabBarDestination.allCases.count)
        XCTAssertEqual(controllers.map { $0.tabBarItem.title }, MainTabBarDestination.allCases.map { Optional($0.title) })
        let defi = try XCTUnwrap(controllers[MainTabBarDestination.defi.rawValue] as? UINavigationController)
        XCTAssertTrue(defi.viewControllers.first is DeFiHubViewController)
        let crossChain = try XCTUnwrap(controllers[MainTabBarDestination.crossChain.rawValue] as? UINavigationController)
        XCTAssertTrue(crossChain.viewControllers.first is CrossChainRootViewController)
        let swap = try XCTUnwrap(controllers[MainTabBarDestination.polkaswap.rawValue] as? UINavigationController)
        XCTAssertTrue(swap.viewControllers.first is FeatureUnavailableViewController)
        XCTAssertNil(swap.tabBarItem.image)
        XCTAssertNil(MainTabBarViewFactory.createAvailablePolkaswapController(wallet: wallet))
    }
}
