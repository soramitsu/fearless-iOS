import XCTest
import UIKit
import SSFModels
@testable import fearless

final class CovHSendRoutersTests: XCTestCase {
    private func makeHost() -> (CovHSendHostController, CovHSendNavigationController) {
        let host = CovHSendHostController()
        let navigation = CovHSendNavigationController()
        navigation.viewControllers = [host]
        return (host, navigation)
    }

    func testSendRouterPresentsEveryPicker() throws {
        let (host, _) = makeHost()
        let router = SendRouter()
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Router", assetUtility: true)
        let presenter = CovHSendPresenterHarness(initialData: .chainAsset(chainAsset)).presenter

        router.presentScan(from: host, moduleOutput: presenter)
        router.presentHistory(from: host, wallet: wallet, chainAsset: try CovHSendFixtures.bitcoin(), moduleOutput: presenter)
        router.showSelectNetwork(from: host, wallet: wallet, selectedChainId: nil, chainModels: [chainAsset.chain], delegate: presenter)
        router.showSelectAsset(from: host, wallet: wallet, selectedAssetId: nil, chainAssets: [chainAsset], output: presenter)
        router.showManageAsset(from: host, wallet: wallet)
        router.presentFormWarning(viewModel: SheetAlertPresentableViewModel(title: "t", message: "m", actions: [], closeAction: nil), from: host)

        XCTAssertEqual(host.presented.count, 6)
        XCTAssertTrue(host.presented[1] is FearlessNavigationController, "History opens in its own navigation stack")
        XCTAssertTrue(host.presented[5] is SheetAletViewController)
        XCTAssertEqual(host.presented[5].modalPresentationStyle, .custom)
        router.presentFormWarning(viewModel: SheetAlertPresentableViewModel(title: "t", message: nil, actions: [], closeAction: nil), from: nil)
        XCTAssertEqual(host.presented.count, 6)
    }

    func testSendRouterPushesConfirmOnlyForTheCurrentSelection() throws {
        let (host, navigation) = makeHost()
        let router = SendRouter()
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Confirm", assetUtility: true)
        let transfer = Transfer(chainAsset: chainAsset, amount: 1, receiver: "receiver", tip: nil, appId: nil)
        let authority = SelectedWalletAuthority()
        authority.publish(wallet)
        let stale = authority.capture(for: wallet)
        authority.publish(AccountGenerator.generateMetaAccount())

        router.presentConfirm(
            from: host, wallet: wallet, chainAsset: chainAsset, call: .transfer(transfer), scamInfo: nil, feeViewModel: nil, selection: stale
        )
        XCTAssertTrue(navigation.pushed.isEmpty, "A replaced wallet selection never opens a confirmation")

        router.presentConfirm(
            from: host, wallet: wallet, chainAsset: chainAsset, call: .transfer(transfer), scamInfo: nil, feeViewModel: nil, selection: nil
        )
        XCTAssertEqual(navigation.pushed.count, 1)
        XCTAssertTrue(navigation.pushed.first is WalletSendConfirmViewProtocol)
    }

    func testCrossChainRouterPresentsPickersHistoryAndWallets() throws {
        let (host, _) = makeHost()
        let router = CrossChainRouter()
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh XRouter", assetUtility: true)
        let presenter = CovHSendPresenterHarness(initialData: .chainAsset(chainAsset)).presenter
        let crossChain = try CovHCrossChainHarness().presenter

        router.showSelectNetwork(
            from: host, wallet: wallet, selectedChainId: chainAsset.chain.chainId, chainModels: [chainAsset.chain], contextTag: 1, delegate: presenter
        )
        router.showSelectAsset(from: host, wallet: wallet, chainAssets: [chainAsset], selectedAssetId: chainAsset.asset.id, output: presenter)
        router.presentScan(from: host, moduleOutput: presenter)
        router.presentHistory(from: host, wallet: wallet, chainAsset: try CovHSendFixtures.bitcoin(), moduleOutput: presenter)
        router.showWalletManagment(selectedWalletId: wallet.metaId, from: host, moduleOutput: crossChain)
        XCTAssertEqual(host.presented.count, 5)
        XCTAssertTrue(host.presented[3] is FearlessNavigationController)
    }

    func testSendAssemblyBuildsTheSendScreenForEveryStart() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Assembly", assetUtility: true)
        let fromAsset = try XCTUnwrap(SendAssembly.configureModule(wallet: wallet, initialData: .chainAsset(chainAsset)))
        XCTAssertTrue(fromAsset.view.controller is SendViewController)
        XCTAssertTrue(fromAsset.input is SendPresenter)
        let fromAddress = try XCTUnwrap(SendAssembly.configureModule(wallet: wallet, initialData: .address("recipient")))
        XCTAssertFalse(fromAddress.view.controller.isViewLoaded, "Nothing is loaded before the screen is shown")
    }

    func testConfirmWireframeClosesFinishesAndCompletesOnThePresenter() throws {
        let (host, navigation) = makeHost()
        let origin = CovHSendHostController()
        navigation.fakePresenter = origin
        let wireframe = WalletSendConfirmWireframe()
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Done", assetUtility: true)

        wireframe.close(view: host)
        XCTAssertEqual(navigation.pops, 1)
        wireframe.finish(view: host)
        XCTAssertEqual(navigation.dismissals, 1)

        wireframe.complete(on: host, title: "0xhash", chainAsset: chainAsset)
        XCTAssertEqual(navigation.dismissals, 2)
        XCTAssertEqual(origin.presented.count, 1)
        XCTAssertEqual(origin.presented.first?.modalPresentationStyle, .custom)

        var completed = false
        wireframe.completeAfterPresentation(on: host, title: "0xhash", chainAsset: chainAsset) { completed = true }
        XCTAssertEqual(origin.presented.count, 2)
        XCTAssertTrue(completed, "The receipt boundary is reached only after presentation")
    }
}

final class CovHSendHostController: UIViewController, ControllerBackedProtocol {
    var presented: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presented.append(viewControllerToPresent)
        completion?()
    }
}

final class CovHSendNavigationController: UINavigationController {
    var pushed: [UIViewController] = []
    var pops = 0
    var dismissals = 0
    var fakePresenter: UIViewController?

    override var presentingViewController: UIViewController? { fakePresenter }

    override func pushViewController(_ viewController: UIViewController, animated _: Bool) {
        pushed.append(viewController)
    }

    override func popViewController(animated _: Bool) -> UIViewController? {
        pops += 1
        return nil
    }

    override func dismiss(animated _: Bool, completion: (() -> Void)? = nil) {
        dismissals += 1
        completion?()
    }
}
